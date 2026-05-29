defmodule ReportForge.Reports.Worker do
  @moduledoc false

  use Oban.Worker, queue: :reports, max_attempts: 3

  require OpenTelemetry.Tracer, as: Tracer

  alias Oban.Job
  alias ReportForge.Reports
  alias ReportForge.Tracing

  @impl Oban.Worker
  def perform(%Job{
        args: %{"report_id" => report_id} = args,
        attempt: attempt,
        max_attempts: max_attempts
      }) do
    run(report_id, Tracing.context_from_carrier(Map.get(args, "trace_carrier")), %{
      attempt: attempt,
      max_attempts: max_attempts
    })
  end

  @impl Oban.Worker
  def backoff(%Job{attempt: attempt}) do
    trunc(:math.pow(attempt, 2) * 15)
  end

  def run(report_id, parent_context \\ nil, retry_context \\ %{attempt: 1, max_attempts: 1}) do
    Tracing.attach_context(parent_context)

    Tracer.with_span "reports.worker.run", %{
      attributes: [{:"reportforge.report_id", report_id}]
    } do
      try do
        with {:ok, report} <- Reports.begin_processing(report_id),
             :ok <- sleep_step(),
             {:ok, _report} <-
               Reports.advance_processing(report_id, 35, "report.query_finished", %{}),
             :ok <- sleep_step(),
             {:ok, artifact} <- Reports.generate_artifact(report),
             {:ok, _report} <-
               Reports.advance_processing(report_id, 80, "report.storage_staged", %{
                 "byte_size" => artifact.byte_size,
                 "checksum" => artifact.checksum
               }),
             :ok <- sleep_step(),
             {:ok, _report} <- Reports.complete_processing(report_id, artifact) do
          :ok
        else
          :cancelled ->
            :ok

          {:error, :not_found} ->
            :ok

          {:error, {error_code, error_message}} ->
            Tracer.set_status(:error, error_message)
            handle_failure(report_id, error_code, error_message, retry_context)

          {:error, {:generation_failed, error_code, error_message}} ->
            Tracer.set_status(:error, error_message)
            handle_failure(report_id, error_code, error_message, retry_context)
        end
      rescue
        exception ->
          Tracer.record_exception(exception, __STACKTRACE__)
          Tracer.set_status(:error, Exception.message(exception))

          handle_failure(
            report_id,
            "unexpected_error",
            Exception.message(exception),
            retry_context
          )
      end
    end
  end

  defp handle_failure(report_id, error_code, error_message, retry_context) do
    if retryable?(error_code) do
      case Reports.schedule_processing_retry(
             report_id,
             error_code,
             error_message,
             retry_context.attempt,
             retry_context.max_attempts
           ) do
        {:ok, _report} ->
          {:error, error_message}

        {:error, :attempts_exhausted} ->
          Reports.fail_processing(report_id, error_code, error_message)

        other ->
          other
      end
    else
      Reports.fail_processing(report_id, error_code, error_message)
    end
  end

  defp retryable?("source_timeout"), do: true
  defp retryable?("storage_unavailable"), do: true
  defp retryable?("unexpected_error"), do: true
  defp retryable?(_error_code), do: false

  defp sleep_step do
    delay_ms = Application.get_env(:report_forge, :exporter_step_delay_ms, 15)

    if delay_ms > 0 do
      Process.sleep(delay_ms)
    end

    :ok
  end
end
