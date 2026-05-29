defmodule ReportForge.Maintenance.CleanupWorker do
  @moduledoc false

  use Oban.Worker, queue: :maintenance, max_attempts: 1

  alias Oban.Job
  alias ReportForge.Audit
  alias ReportForge.Maintenance
  alias ReportForge.Observability
  alias ReportForge.Telemetry

  @impl Oban.Worker
  def perform(%Job{args: %{"task" => "purge_expired_artifacts"}}) do
    result = Maintenance.purge_expired_artifacts()

    Observability.log(:info, "maintenance_cleanup_completed", %{
      task: "purge_expired_artifacts",
      artifact_delete_count: result.artifact_delete_count,
      report_update_count: result.report_update_count
    })

    Audit.record_best_effort(%{
      actor_type: "system",
      action: "maintenance.purge_expired_artifacts",
      resource_type: "maintenance_task",
      resource_id: "purge_expired_artifacts",
      metadata: result
    })

    Telemetry.cleanup_completed("purge_expired_artifacts", result)

    :ok
  end

  def perform(%Job{args: %{"task" => "purge_retained_reports"}}) do
    result = Maintenance.purge_retained_reports()

    Observability.log(:info, "maintenance_cleanup_completed", %{
      task: "purge_retained_reports",
      report_delete_count: result.report_delete_count
    })

    Audit.record_best_effort(%{
      actor_type: "system",
      action: "maintenance.purge_retained_reports",
      resource_type: "maintenance_task",
      resource_id: "purge_retained_reports",
      metadata: result
    })

    Telemetry.cleanup_completed("purge_retained_reports", result)

    :ok
  end

  def perform(%Job{}) do
    case Maintenance.run_cleanup() do
      {:ok, result} ->
        Observability.log(
          :info,
          "maintenance_cleanup_completed",
          Map.put(result, :task, "run_cleanup")
        )

        Audit.record_best_effort(%{
          actor_type: "system",
          action: "maintenance.run_cleanup",
          resource_type: "maintenance_task",
          resource_id: "run_cleanup",
          metadata: result
        })

        Telemetry.cleanup_completed("run_cleanup", result)

        :ok

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
