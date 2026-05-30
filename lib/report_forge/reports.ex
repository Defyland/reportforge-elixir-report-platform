defmodule ReportForge.Reports do
  @moduledoc false

  import Ecto.Query
  require OpenTelemetry.Tracer, as: Tracer

  alias Ecto.Changeset
  alias ReportForge
  alias ReportForge.ArtifactStorage
  alias ReportForge.Audit
  alias ReportForge.Identity.Organization
  alias ReportForge.Oban
  alias ReportForge.Observability
  alias ReportForge.Repo
  alias ReportForge.Reports.{Generator, Report, ReportEvent, StateMachine, Worker}
  alias ReportForge.Signing
  alias ReportForge.Telemetry
  alias ReportForge.Tracing

  def list_reports(%Organization{id: organization_id}, filters \\ %{}) do
    Report
    |> where([report], report.organization_id == ^organization_id)
    |> maybe_filter_by_status(filters)
    |> maybe_filter_by_template(filters)
    |> maybe_filter_by_format(filters)
    |> order_by([report], desc: report.inserted_at)
    |> Repo.all()
  end

  def get_report(%Organization{id: organization_id}, report_id) do
    case Repo.get_by(Report, id: report_id, organization_id: organization_id) do
      %Report{} = report -> {:ok, report}
      nil -> {:error, :not_found}
    end
  end

  def list_report_events(%Organization{id: organization_id}, report_id) do
    with {:ok, _report} <- get_report(%Organization{id: organization_id}, report_id) do
      {:ok,
       Repo.all(
         from(event in ReportEvent,
           where: event.report_id == ^report_id,
           order_by: [asc: event.inserted_at]
         )
       )}
    end
  end

  def create_report(%Organization{} = organization, attrs) do
    Tracer.with_span "reports.create_report", %{
      attributes: [{:"reportforge.organization_id", organization.id}]
    } do
      with {:ok, normalized} <- Generator.normalize_request(attrs) do
        fingerprint = Generator.fingerprint(organization.id, normalized)
        now = ReportForge.utc_now()
        trace_carrier = Tracing.current_carrier()

        case Repo.transaction(fn ->
               case find_existing_report_by_idempotency(
                      organization.id,
                      normalized.idempotency_key
                    ) || find_active_report_by_fingerprint(organization.id, fingerprint) do
                 %Report{} = existing_report ->
                   %{report: existing_report, deduplicated?: true}

                 nil ->
                   report =
                     %Report{
                       id: ReportForge.generate_id("rpt"),
                       organization_id: organization.id,
                       template_name: normalized.template_name,
                       format: normalized.format,
                       status: "queued",
                       requested_by: normalized.requested_by,
                       filters: normalized.filters,
                       columns: normalized.columns,
                       idempotency_key: normalized.idempotency_key,
                       fingerprint: fingerprint,
                       correlation_id: normalized.correlation_id,
                       progress_pct: 0,
                       row_count: 0,
                       byte_size: 0,
                       attempt_count: 1,
                       inserted_at: now,
                       updated_at: now
                     }

                   report_event =
                     event(
                       report.id,
                       report.correlation_id,
                       "report.requested",
                       report.status,
                       report.progress_pct,
                       %{}
                     )

                   with {:ok, inserted_report} <- persist_report(report),
                        {:ok, _event} <- persist_event(report_event),
                        {:ok, job} <- enqueue_report(inserted_report.id, trace_carrier),
                        {:ok, queued_report} <-
                          update_report(inserted_report, %{
                            execution_job_id: job.id,
                            updated_at: ReportForge.utc_now()
                          }) do
                     %{report: queued_report, deduplicated?: false}
                   else
                     {:error, %Changeset{} = changeset} ->
                       case deduplicated_report_from_conflict(
                              changeset,
                              organization.id,
                              normalized.idempotency_key,
                              fingerprint
                            ) do
                         %Report{} = existing_report ->
                           %{report: existing_report, deduplicated?: true}

                         nil ->
                           Repo.rollback(changeset)
                       end
                   end
               end
             end) do
          {:ok, result} ->
            Audit.record_best_effort(%{
              organization_id: organization.id,
              action: "report.requested",
              resource_type: "report",
              resource_id: result.report.id,
              metadata: %{
                "template_name" => result.report.template_name,
                "format" => result.report.format,
                "deduplicated" => result.deduplicated?
              }
            })

            Telemetry.report_created(
              normalized.template_name,
              normalized.format,
              result.deduplicated?
            )

            Observability.log(:info, "report_requested", %{
              organization_id: organization.id,
              report_id: result.report.id,
              template_name: result.report.template_name,
              format: result.report.format,
              deduplicated: result.deduplicated?
            })

            {:ok, result}

          {:error, %Changeset{} = changeset} ->
            {:error, {:validation_failed, translate_changeset_errors(changeset)}}
        end
      end
    end
  end

  def cancel_report(%Organization{id: organization_id}, report_id) do
    Tracer.with_span "reports.cancel_report", %{
      attributes: [
        {:"reportforge.organization_id", organization_id},
        {:"reportforge.report_id", report_id}
      ]
    } do
      case Repo.transaction(fn ->
             case load_locked_report(report_id) do
               nil ->
                 Repo.rollback(:not_found)

               %Report{organization_id: ^organization_id} = report ->
                 with {:ok, next_status} <- StateMachine.transition(report.status, :cancel),
                      {:ok, updated_report} <-
                        update_report(report, %{
                          status: next_status,
                          progress_pct:
                            if(report.progress_pct == 100, do: 99, else: report.progress_pct),
                          cancelled_at: ReportForge.utc_now(),
                          updated_at: ReportForge.utc_now(),
                          execution_job_id: nil,
                          last_error_code: nil,
                          last_error: nil
                        }),
                      {:ok, _event} <-
                        persist_event(
                          event(
                            report.id,
                            report.correlation_id,
                            "report.cancelled",
                            updated_report.status,
                            updated_report.progress_pct,
                            %{}
                          )
                        ) do
                   %{report: updated_report, execution_job_id: report.execution_job_id}
                 else
                   :error ->
                     Repo.rollback(
                       {:conflict, "report cannot be cancelled from its current state"}
                     )

                   {:error, %Changeset{} = changeset} ->
                     Repo.rollback(changeset)
                 end

               _other ->
                 Repo.rollback(:not_found)
             end
           end) do
        {:ok, %{report: report, execution_job_id: execution_job_id}} ->
          if is_integer(execution_job_id) do
            Oban.cancel_job(execution_job_id)
          end

          Audit.record_best_effort(%{
            organization_id: organization_id,
            action: "report.cancelled",
            resource_type: "report",
            resource_id: report.id,
            metadata: %{"status" => report.status}
          })

          Observability.log(:warning, "report_cancelled", %{
            organization_id: organization_id,
            report_id: report.id,
            status: report.status
          })

          {:ok, report}

        {:error, :not_found} ->
          {:error, :not_found}

        {:error, {:conflict, _message} = conflict} ->
          {:error, conflict}

        {:error, %Changeset{} = changeset} ->
          {:error, {:validation_failed, translate_changeset_errors(changeset)}}
      end
    end
  end

  def retry_report(%Organization{id: organization_id}, report_id) do
    Tracer.with_span "reports.retry_report", %{
      attributes: [
        {:"reportforge.organization_id", organization_id},
        {:"reportforge.report_id", report_id}
      ]
    } do
      trace_carrier = Tracing.current_carrier()

      case Repo.transaction(fn ->
             case load_locked_report(report_id) do
               nil ->
                 Repo.rollback(:not_found)

               %Report{organization_id: ^organization_id} = report ->
                 with {:ok, next_status} <- StateMachine.transition(report.status, :retry),
                      _deleted_artifacts <- ArtifactStorage.delete_for_report(report.id),
                      {:ok, updated_report} <-
                        update_report(report, %{
                          status: next_status,
                          progress_pct: 0,
                          row_count: 0,
                          byte_size: 0,
                          checksum: nil,
                          artifact_token: nil,
                          artifact_filename: nil,
                          artifact_content_type: nil,
                          download_expires_at: nil,
                          started_at: nil,
                          completed_at: nil,
                          failed_at: nil,
                          cancelled_at: nil,
                          execution_job_id: nil,
                          last_error_code: nil,
                          last_error: nil,
                          attempt_count: report.attempt_count + 1,
                          updated_at: ReportForge.utc_now()
                        }),
                      {:ok, _event} <-
                        persist_event(
                          event(
                            report.id,
                            report.correlation_id,
                            "report.retry_requested",
                            updated_report.status,
                            updated_report.progress_pct,
                            %{"attempt_count" => updated_report.attempt_count}
                          )
                        ),
                      {:ok, job} <- enqueue_report(report.id, trace_carrier),
                      {:ok, queued_report} <-
                        update_report(updated_report, %{
                          execution_job_id: job.id,
                          updated_at: ReportForge.utc_now()
                        }) do
                   queued_report
                 else
                   :error ->
                     Repo.rollback({:conflict, "report cannot be retried from its current state"})

                   {:error, %Changeset{} = changeset} ->
                     Repo.rollback(changeset)
                 end

               _other ->
                 Repo.rollback(:not_found)
             end
           end) do
        {:ok, report} ->
          Audit.record_best_effort(%{
            organization_id: organization_id,
            action: "report.retry_requested",
            resource_type: "report",
            resource_id: report.id,
            metadata: %{"attempt_count" => report.attempt_count}
          })

          Observability.log(:info, "report_retry_requested", %{
            organization_id: organization_id,
            report_id: report.id,
            attempt_count: report.attempt_count
          })

          {:ok, report}

        {:error, :not_found} ->
          {:error, :not_found}

        {:error, {:conflict, _message} = conflict} ->
          {:error, conflict}

        {:error, %Changeset{} = changeset} ->
          {:error, {:validation_failed, translate_changeset_errors(changeset)}}
      end
    end
  end

  def get_download_link(%Organization{id: organization_id}, report_id) do
    with {:ok, %Report{organization_id: ^organization_id} = report} <-
           get_report(%Organization{id: organization_id}, report_id),
         {:ok, artifact} <- ArtifactStorage.fetch_artifact(report.artifact_token) do
      Audit.record_best_effort(%{
        organization_id: organization_id,
        action: "report.download_link_resolved",
        resource_type: "report",
        resource_id: report.id,
        metadata: %{"artifact_id" => artifact.id, "filename" => artifact.filename}
      })

      {:ok,
       %{
         report_id: report.id,
         url: Signing.download_url(report.artifact_token),
         filename: artifact.filename,
         content_type: artifact.content_type,
         expires_at: ReportForge.to_iso8601(report.download_expires_at)
       }}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, :gone} -> {:error, :gone}
      _other -> {:error, {:conflict, "report artifact is not available yet"}}
    end
  end

  def download_artifact(token) when is_binary(token) do
    with {:ok, payload} <- Signing.verify_download(token),
         {:ok, artifact} <- ArtifactStorage.fetch_artifact(token),
         true <- payload["report_id"] == artifact.report_id,
         {:ok, source} <- ArtifactStorage.open_artifact(artifact) do
      Audit.record_best_effort(%{
        organization_id: artifact.organization_id,
        actor_type: "signed_url",
        action: "report.artifact_downloaded",
        resource_type: "report",
        resource_id: artifact.report_id,
        metadata: %{"artifact_id" => artifact.id, "filename" => artifact.filename}
      })

      {:ok, %{artifact: artifact, source: source}}
    else
      false -> {:error, :not_found}
      {:error, :invalid_signature} -> {:error, :not_found}
      {:error, _reason} = error -> error
    end
  end

  def begin_processing(report_id) do
    case Repo.transaction(fn ->
           case load_locked_report(report_id) do
             %Report{} = report ->
               with {:ok, next_status} <- StateMachine.transition(report.status, :start),
                    {:ok, updated_report} <-
                      update_report(report, %{
                        status: next_status,
                        started_at: ReportForge.utc_now(),
                        progress_pct: 10,
                        updated_at: ReportForge.utc_now()
                      }),
                    {:ok, _event} <-
                      persist_event(
                        event(
                          report.id,
                          report.correlation_id,
                          "report.started",
                          updated_report.status,
                          updated_report.progress_pct,
                          %{}
                        )
                      ) do
                 updated_report
               else
                 :error ->
                   Repo.rollback(:cancelled)

                 {:error, %Changeset{} = changeset} ->
                   Repo.rollback(changeset)
               end

             nil ->
               Repo.rollback(:not_found)
           end
         end) do
      {:ok, updated_report} ->
        Logger.metadata(
          report_id: updated_report.id,
          organization_id: updated_report.organization_id,
          correlation_id: updated_report.correlation_id
        )

        Observability.log(:info, "report_started", %{
          report_id: updated_report.id,
          organization_id: updated_report.organization_id
        })

        {:ok, updated_report}

      {:error, :cancelled} ->
        :cancelled

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, %Changeset{} = changeset} ->
        {:error, {:validation_failed, translate_changeset_errors(changeset)}}
    end
  end

  def advance_processing(report_id, progress_pct, event_type, metadata) do
    case Repo.transaction(fn ->
           case load_locked_report(report_id) do
             %Report{status: "running"} = report ->
               with {:ok, updated_report} <-
                      update_report(report, %{
                        progress_pct: progress_pct,
                        updated_at: ReportForge.utc_now()
                      }),
                    {:ok, _event} <-
                      persist_event(
                        event(
                          report.id,
                          report.correlation_id,
                          event_type,
                          updated_report.status,
                          progress_pct,
                          metadata
                        )
                      ) do
                 updated_report
               else
                 {:error, %Changeset{} = changeset} ->
                   Repo.rollback(changeset)
               end

             %Report{status: "cancelled"} ->
               Repo.rollback(:cancelled)

             %Report{status: status} ->
               Repo.rollback({status, "report is no longer running"})

             nil ->
               Repo.rollback(:not_found)
           end
         end) do
      {:ok, updated_report} ->
        {:ok, updated_report}

      {:error, :cancelled} ->
        :cancelled

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, {status, message}} when is_binary(status) ->
        {:error, {status, message}}

      {:error, %Changeset{} = changeset} ->
        {:error, {:validation_failed, translate_changeset_errors(changeset)}}
    end
  end

  def generate_artifact(%Report{} = report) do
    case Generator.generate(report) do
      {:ok, artifact} ->
        {:ok, artifact}

      {:error, {error_code, error_message}} ->
        {:error, {:generation_failed, error_code, error_message}}
    end
  end

  def complete_processing(report_id, artifact) do
    case Repo.transaction(fn ->
           case load_locked_report(report_id) do
             %Report{status: "running"} = report ->
               with {:ok, next_status} <- StateMachine.transition(report.status, :complete) do
                 now = ReportForge.utc_now()

                 download_expires_at =
                   DateTime.add(
                     now,
                     Application.get_env(:report_forge, :report_ttl_seconds, 86_400),
                     :second
                   )

                 token =
                   Signing.sign_download(%{
                     report_id: report.id,
                     organization_id: report.organization_id,
                     exp: DateTime.to_unix(download_expires_at)
                   })

                 with {:ok, stored_artifact} <-
                        ArtifactStorage.put_artifact(%{
                          id: ReportForge.generate_id("art"),
                          report_id: report.id,
                          organization_id: report.organization_id,
                          token: token,
                          body: artifact.body,
                          filename: artifact.filename,
                          content_type: artifact.content_type,
                          expires_at: download_expires_at
                        }),
                      {:ok, _uploaded_event} <-
                        persist_event(
                          event(
                            report.id,
                            report.correlation_id,
                            "report.uploaded",
                            report.status,
                            90,
                            %{
                              "storage_key" => stored_artifact.storage_key,
                              "byte_size" => stored_artifact.byte_size,
                              "checksum" => stored_artifact.checksum,
                              "content_type" => stored_artifact.content_type
                            }
                          )
                        ),
                      {:ok, updated_report} <-
                        update_report(report, %{
                          status: next_status,
                          progress_pct: 100,
                          row_count: artifact.row_count,
                          byte_size: artifact.byte_size,
                          checksum: artifact.checksum,
                          execution_job_id: nil,
                          artifact_token: token,
                          artifact_filename: artifact.filename,
                          artifact_content_type: artifact.content_type,
                          download_expires_at: download_expires_at,
                          completed_at: now,
                          last_error_code: nil,
                          last_error: nil,
                          updated_at: now
                        }),
                      {:ok, _completed_event} <-
                        persist_event(
                          event(
                            report.id,
                            report.correlation_id,
                            "report.completed",
                            updated_report.status,
                            updated_report.progress_pct,
                            %{
                              "row_count" => artifact.row_count,
                              "byte_size" => artifact.byte_size,
                              "checksum" => artifact.checksum
                            }
                          )
                        ) do
                   %{report: updated_report, duration_ms: duration_ms(report.started_at, now)}
                 else
                   {:error, %Changeset{} = changeset} ->
                     Repo.rollback(changeset)

                   {:error, {error_code, error_message}} ->
                     Repo.rollback({error_code, error_message})
                 end
               else
                 :error ->
                   Repo.rollback({:conflict, "report cannot be completed from its current state"})
               end

             %Report{status: "cancelled"} ->
               Repo.rollback(:cancelled)

             %Report{status: status} ->
               Repo.rollback({status, "report cannot be completed from its current state"})

             nil ->
               Repo.rollback(:not_found)
           end
         end) do
      {:ok, %{report: updated_report, duration_ms: duration_ms}} ->
        Telemetry.report_completed(updated_report.status, duration_ms)

        Observability.log(:info, "report_completed", %{
          report_id: updated_report.id,
          duration_ms: duration_ms,
          row_count: updated_report.row_count
        })

        {:ok, updated_report}

      {:error, :cancelled} ->
        :cancelled

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, {status, message}} when is_binary(status) ->
        {:error, {status, message}}

      {:error, {:conflict, _message} = conflict} ->
        {:error, conflict}

      {:error, %Changeset{} = changeset} ->
        {:error, {:validation_failed, translate_changeset_errors(changeset)}}
    end
  end

  def schedule_processing_retry(report_id, error_code, error_message, attempt, max_attempts) do
    case Repo.transaction(fn ->
           case load_locked_report(report_id) do
             %Report{status: "running"} = report when attempt < max_attempts ->
               with {:ok, updated_report} <-
                      update_report(report, %{
                        status: "queued",
                        progress_pct: 0,
                        attempt_count: max(report.attempt_count, attempt + 1),
                        last_error_code: error_code,
                        last_error: error_message,
                        updated_at: ReportForge.utc_now()
                      }),
                    {:ok, _event} <-
                      persist_event(
                        event(
                          report.id,
                          report.correlation_id,
                          "report.retry_scheduled",
                          updated_report.status,
                          updated_report.progress_pct,
                          %{
                            "error_code" => error_code,
                            "attempt" => attempt,
                            "max_attempts" => max_attempts
                          }
                        )
                      ) do
                 updated_report
               else
                 {:error, %Changeset{} = changeset} ->
                   Repo.rollback(changeset)
               end

             %Report{status: "running"} ->
               Repo.rollback(:attempts_exhausted)

             %Report{status: "cancelled"} ->
               Repo.rollback(:cancelled)

             nil ->
               Repo.rollback(:not_found)
           end
         end) do
      {:ok, updated_report} ->
        Telemetry.report_retry_scheduled(error_code, attempt, max_attempts)
        {:ok, updated_report}

      {:error, :attempts_exhausted} ->
        {:error, :attempts_exhausted}

      {:error, :cancelled} ->
        :cancelled

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, %Changeset{} = changeset} ->
        {:error, {:validation_failed, translate_changeset_errors(changeset)}}
    end
  end

  def fail_processing(report_id, error_code, error_message) do
    case Repo.transaction(fn ->
           case load_locked_report(report_id) do
             %Report{status: "running"} = report ->
               with {:ok, next_status} <- StateMachine.transition(report.status, :fail),
                    {:ok, updated_report} <-
                      update_report(report, %{
                        status: next_status,
                        failed_at: ReportForge.utc_now(),
                        updated_at: ReportForge.utc_now(),
                        execution_job_id: nil,
                        last_error_code: error_code,
                        last_error: error_message
                      }),
                    {:ok, _event} <-
                      persist_event(
                        event(
                          report.id,
                          report.correlation_id,
                          "report.failed",
                          updated_report.status,
                          updated_report.progress_pct,
                          %{"error_code" => error_code}
                        )
                      ) do
                 %{
                   report: updated_report,
                   duration_ms: duration_ms(report.started_at, ReportForge.utc_now())
                 }
               else
                 :error ->
                   Repo.rollback({:conflict, "report cannot fail from its current state"})

                 {:error, %Changeset{} = changeset} ->
                   Repo.rollback(changeset)
               end

             %Report{status: "cancelled"} ->
               Repo.rollback(:cancelled)

             nil ->
               Repo.rollback(:not_found)
           end
         end) do
      {:ok, %{report: updated_report, duration_ms: duration_ms}} ->
        Telemetry.report_completed(updated_report.status, duration_ms)

        Observability.log(:warning, "report_failed", %{
          report_id: updated_report.id,
          error_code: error_code,
          error_message: error_message
        })

        {:ok, updated_report}

      {:error, :cancelled} ->
        :cancelled

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, {:conflict, _message} = conflict} ->
        {:error, conflict}

      {:error, %Changeset{} = changeset} ->
        {:error, {:validation_failed, translate_changeset_errors(changeset)}}
    end
  end

  defp enqueue_report(report_id, trace_carrier) do
    report_id
    |> worker_args(trace_carrier)
    |> Worker.new()
    |> Oban.insert()
  end

  defp find_existing_report_by_idempotency(_organization_id, nil), do: nil
  defp find_existing_report_by_idempotency(_organization_id, ""), do: nil

  defp find_existing_report_by_idempotency(organization_id, idempotency_key) do
    Repo.one(
      from(report in Report,
        where:
          report.organization_id == ^organization_id and
            report.idempotency_key == ^idempotency_key,
        limit: 1
      )
    )
  end

  defp find_active_report_by_fingerprint(organization_id, fingerprint) do
    Repo.one(
      from(report in Report,
        where:
          report.organization_id == ^organization_id and
            report.fingerprint == ^fingerprint and
            report.status in ^["queued", "running", "succeeded"],
        limit: 1
      )
    )
  end

  defp deduplicated_report_from_conflict(
         %Changeset{} = changeset,
         organization_id,
         idempotency_key,
         fingerprint
       ) do
    if unique_error?(changeset, :idempotency_key) do
      find_existing_report_by_idempotency(organization_id, idempotency_key)
    else
      if unique_error?(changeset, :fingerprint) do
        find_active_report_by_fingerprint(organization_id, fingerprint)
      else
        nil
      end
    end
  end

  defp persist_report(%Report{} = report) do
    %Report{}
    |> Report.changeset(Map.from_struct(report))
    |> Repo.insert()
  end

  defp persist_event(%ReportEvent{} = report_event) do
    %ReportEvent{}
    |> ReportEvent.changeset(Map.from_struct(report_event))
    |> Repo.insert()
  end

  defp load_locked_report(report_id) do
    Repo.one(from(report in Report, where: report.id == ^report_id, lock: "FOR UPDATE"))
  end

  defp update_report(%Report{} = report, attrs) do
    report |> Changeset.change(attrs) |> Repo.update()
  end

  defp worker_args(report_id, trace_carrier) do
    %{
      "report_id" => report_id,
      "trace_carrier" => trace_carrier
    }
  end

  defp maybe_filter_by_status(query, %{"status" => status}),
    do: where(query, [report], report.status == ^status)

  defp maybe_filter_by_status(query, %{status: status}),
    do: where(query, [report], report.status == ^status)

  defp maybe_filter_by_status(query, _filters), do: query

  defp maybe_filter_by_template(query, %{"template_name" => template_name}),
    do: where(query, [report], report.template_name == ^template_name)

  defp maybe_filter_by_template(query, %{template_name: template_name}),
    do: where(query, [report], report.template_name == ^template_name)

  defp maybe_filter_by_template(query, _filters), do: query

  defp maybe_filter_by_format(query, %{"format" => format}),
    do: where(query, [report], report.format == ^format)

  defp maybe_filter_by_format(query, %{format: format}),
    do: where(query, [report], report.format == ^format)

  defp maybe_filter_by_format(query, _filters), do: query

  defp event(report_id, correlation_id, event_type, status, progress_pct, metadata) do
    trace_metadata = Tracing.trace_metadata()

    %ReportEvent{
      id: ReportForge.generate_id("evt"),
      report_id: report_id,
      event_type: event_type,
      status: status,
      progress_pct: progress_pct,
      correlation_id: correlation_id,
      trace_id: trace_metadata[:trace_id],
      span_id: trace_metadata[:span_id],
      metadata: metadata,
      inserted_at: ReportForge.utc_now()
    }
  end

  defp unique_error?(%Changeset{errors: errors}, field) do
    Enum.any?(errors, fn
      {^field, {"has already been taken", _opts}} -> true
      _other -> false
    end)
  end

  defp translate_changeset_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message ->
        %{field: to_string(field), issue: message}
      end)
    end)
  end

  defp duration_ms(nil, _finished_at), do: 0

  defp duration_ms(started_at, finished_at),
    do: DateTime.diff(finished_at, started_at, :millisecond)
end
