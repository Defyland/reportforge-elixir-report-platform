defmodule ReportForge.Reports.WorkerTest do
  use ReportForge.Case, async: false

  alias ReportForge.Reports
  alias ReportForge.Reports.Worker

  test "records the full happy-path event sequence for an asynchronous report" do
    %{organization: organization} = Fixtures.organization_fixture()

    report =
      Fixtures.report_fixture(organization, %{
        "template_name" => "ledger_summary",
        "format" => "json"
      })

    assert_enqueued(worker: ReportForge.Reports.Worker, args: %{"report_id" => report.id})
    assert %{success: 1} = drain_report_jobs()

    assert {:ok, report_events} = Reports.list_report_events(organization, report.id)

    assert Enum.map(report_events, & &1.event_type) == [
             "report.requested",
             "report.started",
             "report.query_finished",
             "report.storage_staged",
             "report.completed"
           ]

    assert report_events
           |> Enum.map(& &1.trace_id)
           |> Enum.uniq()
           |> length() == 1

    assert Enum.all?(report_events, &is_binary(&1.span_id))

    assert report_events
           |> Enum.map(& &1.span_id)
           |> Enum.uniq()
           |> length() >= 2
  end

  test "schedules retryable failures with classified Oban backoff before final failure" do
    %{organization: organization} = Fixtures.organization_fixture()

    report =
      Fixtures.report_fixture(organization, %{
        "filters" => %{"row_limit" => 2, "simulate_failure" => "storage_unavailable"}
      })

    assert Worker.backoff(%Oban.Job{attempt: 2}) == 60

    assert {:error, "object storage upload failed"} =
             Worker.perform(%Oban.Job{
               args: %{"report_id" => report.id},
               attempt: 1,
               max_attempts: 3
             })

    assert {:ok, queued_report} = Reports.get_report(organization, report.id)
    assert queued_report.status == "queued"
    assert queued_report.attempt_count == 2
    assert queued_report.last_error_code == "storage_unavailable"

    assert {:ok, report_events} = Reports.list_report_events(organization, report.id)
    assert Enum.any?(report_events, &(&1.event_type == "report.retry_scheduled"))
  end
end
