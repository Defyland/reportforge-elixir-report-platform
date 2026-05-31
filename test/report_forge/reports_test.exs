defmodule ReportForge.ReportsTest do
  use ReportForge.Case, async: false

  import Ecto.Query

  alias ReportForge.Repo
  alias ReportForge.Reports
  alias ReportForge.Reports.Artifact
  alias ReportForge.Reports.Report
  alias ReportForge.Reports.Worker

  defmodule PausingStorage do
    @behaviour ReportForge.ArtifactStorage

    alias ReportForge.ArtifactStorage.Local

    def put_artifact(attrs) do
      test_pid = Application.fetch_env!(:report_forge, :pausing_storage_test_pid)
      send(test_pid, {:storage_put_started, self()})

      receive do
        :continue_storage_put -> Local.put_artifact(attrs)
      after
        5_000 -> {:error, {"storage_unavailable", "pausing storage timed out"}}
      end
    end

    defdelegate fetch_artifact(token), to: Local
    defdelegate open_artifact(artifact), to: Local
    defdelegate delete_for_report(report_id), to: Local
    defdelegate expired_report_ids(now), to: Local
    defdelegate delete_expired(now), to: Local
  end

  test "deduplicates repeated idempotency keys for the same tenant" do
    %{organization: organization} = Fixtures.organization_fixture()

    payload = %{
      "template_name" => "cash_position",
      "format" => "csv",
      "requested_by" => "finance@example.com",
      "idempotency_key" => "dup-1",
      "filters" => %{"row_limit" => 4}
    }

    assert {:ok, %{report: first_report, deduplicated?: false}} =
             Reports.create_report(organization, payload)

    assert {:ok, %{report: second_report, deduplicated?: true}} =
             Reports.create_report(organization, payload)

    assert second_report.id == first_report.id
  end

  test "deduplicates concurrent idempotency requests for the same tenant" do
    %{organization: organization} = Fixtures.organization_fixture()

    payload = %{
      "template_name" => "cash_position",
      "format" => "csv",
      "requested_by" => "finance@example.com",
      "idempotency_key" => "concurrent-idempotency-key",
      "filters" => %{"row_limit" => 4}
    }

    results = create_reports_concurrently(organization, payload)
    report_ids = Enum.map(results, & &1.report.id)

    assert Enum.uniq(report_ids) |> length() == 1
    assert Enum.count(results, & &1.deduplicated?) == 7
    assert report_count(organization.id, "concurrent-idempotency-key") == 1
  end

  test "deduplicates concurrent equivalent fingerprints without an idempotency key" do
    %{organization: organization} = Fixtures.organization_fixture()

    payload = %{
      "template_name" => "cash_position",
      "format" => "csv",
      "requested_by" => "finance@example.com",
      "filters" => %{"row_limit" => 4}
    }

    results = create_reports_concurrently(organization, payload)
    report_ids = Enum.map(results, & &1.report.id)

    assert Enum.uniq(report_ids) |> length() == 1
    assert Enum.count(results, & &1.deduplicated?) == 7
  end

  test "allows equivalent fingerprints after failed or cancelled terminal reports" do
    %{organization: organization} = Fixtures.organization_fixture()

    payload = %{
      "template_name" => "cash_position",
      "format" => "csv",
      "requested_by" => "finance@example.com",
      "filters" => %{"row_limit" => 4, "simulate_failure" => "source_timeout"}
    }

    assert {:ok, %{report: failed_candidate, deduplicated?: false}} =
             Reports.create_report(organization, payload)

    Enum.each(1..3, fn attempt ->
      Worker.perform(%Oban.Job{
        args: %{"report_id" => failed_candidate.id},
        attempt: attempt,
        max_attempts: 3
      })
    end)

    assert {:ok, %{status: "failed"}} = Reports.get_report(organization, failed_candidate.id)

    assert {:ok, %{report: new_report, deduplicated?: false}} =
             Reports.create_report(organization, payload)

    assert new_report.id != failed_candidate.id

    cancel_payload = %{
      "template_name" => "ledger_summary",
      "format" => "csv",
      "requested_by" => "finance@example.com",
      "filters" => %{"row_limit" => 5}
    }

    assert {:ok, %{report: cancelled_candidate, deduplicated?: false}} =
             Reports.create_report(organization, cancel_payload)

    assert {:ok, cancelled_report} = Reports.cancel_report(organization, cancelled_candidate.id)
    assert cancelled_report.status == "cancelled"

    assert {:ok, %{report: replacement_report, deduplicated?: false}} =
             Reports.create_report(organization, cancel_payload)

    assert replacement_report.id != cancelled_candidate.id
  end

  test "produces an artifact and a signed download url" do
    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"format" => "zip"})

    assert_enqueued(worker: ReportForge.Reports.Worker, args: %{"report_id" => report.id})
    assert %{success: 1} = drain_report_jobs()

    assert {:ok, completed_report} = Reports.get_report(organization, report.id)
    assert completed_report.artifact_filename =~ ".zip"
    assert {:ok, download_link} = Reports.get_download_link(organization, report.id)
    assert download_link.url =~ "/downloads/"
  end

  test "marks a report as failed when the simulated upstream query times out" do
    %{organization: organization} = Fixtures.organization_fixture()

    report =
      Fixtures.report_fixture(organization, %{
        "filters" => %{"row_limit" => 2, "simulate_failure" => "source_timeout"}
      })

    assert {:error, "upstream warehouse query timed out"} =
             Worker.perform(%Oban.Job{
               args: %{"report_id" => report.id},
               attempt: 1,
               max_attempts: 3
             })

    assert {:error, "upstream warehouse query timed out"} =
             Worker.perform(%Oban.Job{
               args: %{"report_id" => report.id},
               attempt: 2,
               max_attempts: 3
             })

    assert {:ok, %{status: "failed"}} =
             Worker.perform(%Oban.Job{
               args: %{"report_id" => report.id},
               attempt: 3,
               max_attempts: 3
             })

    assert {:ok, failed_report} = Reports.get_report(organization, report.id)
    assert failed_report.last_error_code == "source_timeout"
    assert failed_report.attempt_count == 3
  end

  test "cancels a running report and allows a retry back to the queue" do
    original_delay = Application.get_env(:report_forge, :exporter_step_delay_ms)
    Application.put_env(:report_forge, :exporter_step_delay_ms, 50)
    on_exit(fn -> Application.put_env(:report_forge, :exporter_step_delay_ms, original_delay) end)

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"filters" => %{"row_limit" => 10}})
    drainer = Task.async(fn -> drain_report_jobs() end)

    wait_until(fn ->
      match?({:ok, %{status: "running"}}, Reports.get_report(organization, report.id))
    end)

    assert {:ok, cancelled_report} = Reports.cancel_report(organization, report.id)
    assert cancelled_report.status == "cancelled"
    drain_result = Task.await(drainer, 5_000)
    assert drain_result.success + drain_result.cancelled == 1

    assert {:ok, retried_report} = Reports.retry_report(organization, report.id)
    assert retried_report.status == "queued"
    assert retried_report.attempt_count == 2
    assert_enqueued(worker: ReportForge.Reports.Worker, args: %{"report_id" => report.id})
  end

  test "does not hold the report row lock while writing artifact bytes" do
    original_adapter = Application.get_env(:report_forge, :artifact_storage_adapter)
    Application.put_env(:report_forge, :artifact_storage_adapter, PausingStorage)
    Application.put_env(:report_forge, :pausing_storage_test_pid, self())

    on_exit(fn ->
      Application.put_env(:report_forge, :artifact_storage_adapter, original_adapter)
      Application.delete_env(:report_forge, :pausing_storage_test_pid)
    end)

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"filters" => %{"row_limit" => 2}})

    assert {:ok, running_report} = Reports.begin_processing(report.id)
    assert {:ok, artifact} = Reports.generate_artifact(running_report)

    completion_task = Task.async(fn -> Reports.complete_processing(report.id, artifact) end)

    assert_receive {:storage_put_started, storage_pid}, 1_000
    assert {:ok, %Report{id: locked_id}} = lock_report_nowait(report.id)
    assert locked_id == report.id

    send(storage_pid, :continue_storage_put)
    assert {:ok, completed_report} = Task.await(completion_task, 5_000)
    assert completed_report.status == "succeeded"
  end

  test "cleans staged artifact when a report is cancelled before completion finalizes" do
    original_adapter = Application.get_env(:report_forge, :artifact_storage_adapter)
    Application.put_env(:report_forge, :artifact_storage_adapter, PausingStorage)
    Application.put_env(:report_forge, :pausing_storage_test_pid, self())

    on_exit(fn ->
      Application.put_env(:report_forge, :artifact_storage_adapter, original_adapter)
      Application.delete_env(:report_forge, :pausing_storage_test_pid)
    end)

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"filters" => %{"row_limit" => 2}})

    assert {:ok, running_report} = Reports.begin_processing(report.id)
    assert {:ok, artifact} = Reports.generate_artifact(running_report)

    completion_task = Task.async(fn -> Reports.complete_processing(report.id, artifact) end)

    assert_receive {:storage_put_started, storage_pid}, 1_000
    assert {:ok, cancelled_report} = Reports.cancel_report(organization, report.id)
    assert cancelled_report.status == "cancelled"

    send(storage_pid, :continue_storage_put)
    assert :cancelled = Task.await(completion_task, 5_000)

    assert {:ok, final_report} = Reports.get_report(organization, report.id)
    assert final_report.status == "cancelled"
    assert artifact_count(report.id) == 0
  end

  defp create_reports_concurrently(organization, payload) do
    1..8
    |> Task.async_stream(
      fn _index ->
        {:ok, result} = Reports.create_report(organization, payload)
        result
      end,
      max_concurrency: 8,
      timeout: 5_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp report_count(organization_id, idempotency_key) do
    Repo.aggregate(
      from(report in Report,
        where:
          report.organization_id == ^organization_id and
            report.idempotency_key == ^idempotency_key
      ),
      :count
    )
  end

  defp artifact_count(report_id) do
    Repo.aggregate(
      from(artifact in Artifact,
        where: artifact.report_id == ^report_id
      ),
      :count
    )
  end

  defp lock_report_nowait(report_id) do
    Repo.transaction(fn ->
      Repo.query!("SET LOCAL lock_timeout = '100ms'")
      Repo.one(from(report in Report, where: report.id == ^report_id, lock: "FOR UPDATE"))
    end)
  end
end
