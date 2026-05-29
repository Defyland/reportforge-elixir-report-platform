defmodule ReportForge.Telemetry do
  @moduledoc false

  @http_request_event [:report_forge, :http, :request, :stop]
  @report_created_event [:report_forge, :report, :created]
  @report_completed_event [:report_forge, :report, :completed]
  @report_retry_scheduled_event [:report_forge, :report, :retry, :scheduled]
  @cleanup_completed_event [:report_forge, :maintenance, :cleanup, :completed]

  def events do
    [
      @http_request_event,
      @report_created_event,
      @report_completed_event,
      @report_retry_scheduled_event,
      @cleanup_completed_event
    ]
  end

  def http_request(method, path, status, duration_native) do
    :telemetry.execute(
      @http_request_event,
      %{duration: duration_native},
      %{method: method, path: path, status: status}
    )
  end

  def report_created(template_name, format, deduplicated?) do
    :telemetry.execute(
      @report_created_event,
      %{count: 1},
      %{template_name: template_name, format: format, deduplicated?: deduplicated?}
    )
  end

  def report_completed(status, duration_ms) do
    :telemetry.execute(
      @report_completed_event,
      %{duration_ms: duration_ms},
      %{status: status}
    )
  end

  def report_retry_scheduled(error_code, attempt, max_attempts) do
    :telemetry.execute(
      @report_retry_scheduled_event,
      %{count: 1},
      %{error_code: error_code, attempt: attempt, max_attempts: max_attempts}
    )
  end

  def cleanup_completed(task, result) do
    :telemetry.execute(
      @cleanup_completed_event,
      %{count: 1},
      %{task: task, result: result}
    )
  end
end
