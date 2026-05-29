defmodule ReportForge.ReportsTest do
  use ReportForge.Case, async: false

  alias ReportForge.Reports

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

    assert %{success: 1} = drain_report_jobs()

    assert {:ok, failed_report} = Reports.get_report(organization, report.id)
    assert failed_report.last_error_code == "source_timeout"
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
end
