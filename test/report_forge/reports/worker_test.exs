defmodule ReportForge.Reports.WorkerTest do
  use ReportForge.Case, async: false

  alias ReportForge.Reports

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
end
