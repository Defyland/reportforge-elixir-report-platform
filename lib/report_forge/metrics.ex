defmodule ReportForge.Metrics do
  @moduledoc false

  use Agent

  import Ecto.Query

  alias ReportForge.Repo
  alias ReportForge.Reports.Report
  alias ReportForge.Telemetry

  def start_link(_opts) do
    with {:ok, pid} <- Agent.start_link(fn -> initial_state() end, name: __MODULE__) do
      attach_handlers()
      {:ok, pid}
    end
  end

  def reset! do
    Agent.update(__MODULE__, fn _state -> initial_state() end)
  end

  def track_request(method, path, status, duration_native) do
    Telemetry.http_request(method, path, status, duration_native)
  end

  def track_report_created(template_name, format, deduplicated?) do
    Telemetry.report_created(template_name, format, deduplicated?)
  end

  def track_report_completed(status, duration_ms) do
    Telemetry.report_completed(status, duration_ms)
  end

  def handle_event([:report_forge, :http, :request, :stop], measurements, metadata, _config) do
    track_request_metric(metadata.method, metadata.path, metadata.status, measurements.duration)
  end

  def handle_event([:report_forge, :report, :created], _measurements, metadata, _config) do
    track_report_created_metric(metadata.template_name, metadata.format, metadata.deduplicated?)
  end

  def handle_event([:report_forge, :report, :completed], measurements, metadata, _config) do
    track_report_completed_metric(metadata.status, measurements.duration_ms)
  end

  def handle_event(
        [:report_forge, :report, :retry, :scheduled],
        _measurements,
        metadata,
        _config
      ) do
    key = {metadata.error_code, metadata.attempt, metadata.max_attempts}

    Agent.update(__MODULE__, fn state ->
      count = Map.get(state.report_retries, key, 0)
      %{state | report_retries: Map.put(state.report_retries, key, count + 1)}
    end)
  end

  def handle_event(
        [:report_forge, :maintenance, :cleanup, :completed],
        _measurements,
        metadata,
        _config
      ) do
    Agent.update(__MODULE__, fn state ->
      count = Map.get(state.cleanup_runs, metadata.task, 0)
      %{state | cleanup_runs: Map.put(state.cleanup_runs, metadata.task, count + 1)}
    end)
  end

  defp track_request_metric(method, path, status, duration_native) do
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

  defp track_report_created_metric(template_name, format, deduplicated?) do
    key = {template_name, format, deduplicated?}

    Agent.update(__MODULE__, fn state ->
      count = Map.get(state.reports_created, key, 0)
      %{state | reports_created: Map.put(state.reports_created, key, count + 1)}
    end)
  end

  defp track_report_completed_metric(status, duration_ms) do
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
        "# HELP reportforge_report_retries_total Total retryable report failures scheduled for another attempt.",
        "# TYPE reportforge_report_retries_total counter",
        render_report_retries(state.report_retries),
        "# HELP reportforge_cleanup_runs_total Total maintenance cleanup runs grouped by task.",
        "# TYPE reportforge_cleanup_runs_total counter",
        render_cleanup_runs(state.cleanup_runs),
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

  defp render_report_retries(report_retries) when map_size(report_retries) == 0 do
    "reportforge_report_retries_total{error_code=\"source_timeout\",attempt=\"1\",max_attempts=\"3\"} 0"
  end

  defp render_report_retries(report_retries) do
    Enum.map(report_retries, fn {{error_code, attempt, max_attempts}, count} ->
      "reportforge_report_retries_total{error_code=\"#{error_code}\",attempt=\"#{attempt}\",max_attempts=\"#{max_attempts}\"} #{count}"
    end)
  end

  defp render_cleanup_runs(cleanup_runs) when map_size(cleanup_runs) == 0 do
    "reportforge_cleanup_runs_total{task=\"purge_expired_artifacts\"} 0"
  end

  defp render_cleanup_runs(cleanup_runs) do
    Enum.map(cleanup_runs, fn {task, count} ->
      "reportforge_cleanup_runs_total{task=\"#{task}\"} #{count}"
    end)
  end

  defp initial_state do
    %{
      http_requests: %{},
      request_duration_ms_sum: 0,
      request_duration_ms_count: 0,
      reports_created: %{},
      reports_completed: %{},
      report_retries: %{},
      cleanup_runs: %{},
      report_duration_ms_sum: 0,
      report_duration_ms_count: 0
    }
  end

  defp attach_handlers do
    :telemetry.detach(__MODULE__)

    :telemetry.attach_many(
      __MODULE__,
      Telemetry.events(),
      &__MODULE__.handle_event/4,
      nil
    )
  end
end
