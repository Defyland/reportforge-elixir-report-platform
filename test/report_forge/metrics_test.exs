defmodule ReportForge.MetricsTest do
  use ReportForge.Case, async: false

  alias ReportForge.Metrics

  test "renders default prometheus output when no activity has happened yet" do
    body = Metrics.render_prometheus()

    assert body =~
             "reportforge_http_requests_total{method=\"GET\",path=\"/healthz\",status=\"200\"} 0"

    assert body =~ "reportforge_reports_completed_total{status=\"succeeded\"} 0"
    assert body =~ "reportforge_report_retries_total"
    assert body =~ "reportforge_cleanup_runs_total"
    assert body =~ "reportforge_inflight_reports 0"
  end

  test "renders tracked counters after report activity" do
    %{organization: organization} = Fixtures.organization_fixture()
    _report = Fixtures.report_fixture(organization, %{"format" => "csv"})

    assert %{success: 1} = drain_report_jobs()

    Metrics.track_request(
      "GET",
      "/healthz",
      200,
      System.convert_time_unit(5, :millisecond, :native)
    )

    body = Metrics.render_prometheus()

    assert body =~
             "reportforge_http_requests_total{method=\"GET\",path=\"/healthz\",status=\"200\"} 1"

    assert body =~ "reportforge_reports_created_total"
    assert body =~ "reportforge_reports_completed_total{status=\"succeeded\"}"
  end

  test "derives retry metrics from telemetry events" do
    ReportForge.Telemetry.report_retry_scheduled("source_timeout", 1, 3)

    body = Metrics.render_prometheus()

    assert body =~
             "reportforge_report_retries_total{error_code=\"source_timeout\",attempt=\"1\",max_attempts=\"3\"} 1"
  end
end
