defmodule ReportForge.ReportsTest do
  use ReportForge.Case, async: false

  import Ecto.Query

  alias ReportForge.Repo
  alias ReportForge.Reports
  alias ReportForge.Reports.Report
  alias ReportForge.Reports.Worker

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
end
