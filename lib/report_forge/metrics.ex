defmodule ReportForge.Metrics do
  @moduledoc false

  use Agent

  import Ecto.Query

  alias ReportForge.Repo
  alias ReportForge.Reports.Report

  def start_link(_opts) do
    Agent.start_link(fn -> initial_state() end, name: __MODULE__)
  end

  def reset! do
    Agent.update(__MODULE__, fn _state -> initial_state() end)
  end

  def track_request(method, path, status, duration_native) do
    duration_ms = System.convert_time_unit(duration_native, :native, :millisecond)
    key = {method, path, status}

    Agent.update(__MODULE__, fn state ->
      count = Map.get(state.http_requests, key, 0)

      %{
        state
        | http_requests: Map.put(state.http_requests, key, count + 1),
          request_duration_ms_sum: state.request_duration_ms_sum + duration_ms,
          request_duration_ms_count: state.request_duration_ms_count + 1
      }
    end)
  end

  def track_report_created(template_name, format, deduplicated?) do
    key = {template_name, format, deduplicated?}

    Agent.update(__MODULE__, fn state ->
      count = Map.get(state.reports_created, key, 0)
      %{state | reports_created: Map.put(state.reports_created, key, count + 1)}
    end)
  end

  def track_report_completed(status, duration_ms) do
    Agent.update(__MODULE__, fn state ->
      count = Map.get(state.reports_completed, status, 0)

      %{
        state
        | reports_completed: Map.put(state.reports_completed, status, count + 1),
          report_duration_ms_sum: state.report_duration_ms_sum + duration_ms,
          report_duration_ms_count: state.report_duration_ms_count + 1
      }
    end)
  end

  def render_prometheus do
    inflight_reports =
      Repo.aggregate(
        from(report in Report, where: report.status in ^["queued", "running"]),
        :count
      )

    Agent.get(__MODULE__, fn state ->
      [
        "# HELP reportforge_http_requests_total Total HTTP requests handled by ReportForge.",
        "# TYPE reportforge_http_requests_total counter",
        render_http_requests(state.http_requests),
        "# HELP reportforge_http_request_duration_ms_sum Sum of observed request durations in milliseconds.",
        "# TYPE reportforge_http_request_duration_ms_sum counter",
        "reportforge_http_request_duration_ms_sum #{state.request_duration_ms_sum}",
        "# HELP reportforge_http_request_duration_ms_count Count of observed request durations.",
        "# TYPE reportforge_http_request_duration_ms_count counter",
        "reportforge_http_request_duration_ms_count #{state.request_duration_ms_count}",
        "# HELP reportforge_reports_created_total Total report creation requests grouped by template, format, and deduplication outcome.",
        "# TYPE reportforge_reports_created_total counter",
        render_reports_created(state.reports_created),
        "# HELP reportforge_reports_completed_total Total completed report executions grouped by final status.",
        "# TYPE reportforge_reports_completed_total counter",
        render_reports_completed(state.reports_completed),
        "# HELP reportforge_report_duration_ms_sum Sum of report execution durations in milliseconds.",
        "# TYPE reportforge_report_duration_ms_sum counter",
        "reportforge_report_duration_ms_sum #{state.report_duration_ms_sum}",
        "# HELP reportforge_report_duration_ms_count Count of report executions that reached a terminal state.",
        "# TYPE reportforge_report_duration_ms_count counter",
        "reportforge_report_duration_ms_count #{state.report_duration_ms_count}",
        "# HELP reportforge_inflight_reports Current number of queued or running reports.",
        "# TYPE reportforge_inflight_reports gauge",
        "reportforge_inflight_reports #{inflight_reports}"
      ]
      |> List.flatten()
      |> Enum.join("\n")
      |> Kernel.<>("\n")
    end)
  end

  defp render_http_requests(requests) when map_size(requests) == 0 do
    "reportforge_http_requests_total{method=\"GET\",path=\"/healthz\",status=\"200\"} 0"
  end

  defp render_http_requests(requests) do
    Enum.map(requests, fn {{method, path, status}, count} ->
      "reportforge_http_requests_total{method=\"#{method}\",path=\"#{path}\",status=\"#{status}\"} #{count}"
    end)
  end

  defp render_reports_created(reports_created) when map_size(reports_created) == 0 do
    "reportforge_reports_created_total{template_name=\"cash_position\",format=\"csv\",deduplicated=\"false\"} 0"
  end

  defp render_reports_created(reports_created) do
    Enum.map(reports_created, fn {{template_name, format, deduplicated?}, count} ->
      "reportforge_reports_created_total{template_name=\"#{template_name}\",format=\"#{format}\",deduplicated=\"#{deduplicated?}\"} #{count}"
    end)
  end

  defp render_reports_completed(reports_completed) when map_size(reports_completed) == 0 do
    "reportforge_reports_completed_total{status=\"succeeded\"} 0"
  end

  defp render_reports_completed(reports_completed) do
    Enum.map(reports_completed, fn {status, count} ->
      "reportforge_reports_completed_total{status=\"#{status}\"} #{count}"
    end)
  end

  defp initial_state do
    %{
      http_requests: %{},
      request_duration_ms_sum: 0,
      request_duration_ms_count: 0,
      reports_created: %{},
      reports_completed: %{},
      report_duration_ms_sum: 0,
      report_duration_ms_count: 0
    }
  end
end
