defmodule ReportForgeWeb.RequestContext do
  @moduledoc false

  import Plug.Conn

  require OpenTelemetry.Tracer, as: Tracer

  alias ReportForge
  alias ReportForge.Observability
  alias ReportForge.Telemetry
  alias ReportForge.Tracing

  def init(opts), do: opts

  def call(conn, _opts) do
    request_id = header(conn, "x-request-id") || ReportForge.generate_id("req")
    correlation_id = header(conn, "x-correlation-id") || ReportForge.generate_id("cor")
    started_at = System.monotonic_time()
    ctx_token = OpenTelemetry.Ctx.attach(OpenTelemetry.Ctx.new())

    request_span =
      Tracer.start_span("#{conn.method} #{conn.request_path}", %{
        kind: :server,
        attributes: [
          {:"http.method", conn.method},
          {:"http.target", conn.request_path},
          {:"request.id", request_id},
          {:"correlation.id", correlation_id}
        ]
      })

    Tracer.set_current_span(request_span)

    trace_metadata = Tracing.trace_metadata()

    Logger.metadata(
      request_id: request_id,
      correlation_id: correlation_id,
      organization_id: nil,
      api_key_id: nil,
      report_id: nil,
      trace_id: trace_metadata[:trace_id],
      span_id: trace_metadata[:span_id]
    )

    conn
    |> assign(:request_id, request_id)
    |> assign(:correlation_id, correlation_id)
    |> assign(:trace_id, trace_metadata[:trace_id])
    |> assign(:span_id, trace_metadata[:span_id])
    |> assign(:request_span, request_span)
    |> assign(:otel_ctx_token, ctx_token)
    |> assign(:request_started_at, started_at)
    |> put_resp_header("x-request-id", request_id)
    |> put_resp_header("x-correlation-id", correlation_id)
    |> maybe_put_traceparent_header()
    |> register_before_send(fn conn ->
      duration = System.monotonic_time() - conn.assigns.request_started_at
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)
      status = conn.status || 200

      Tracer.set_current_span(conn.assigns.request_span)

      Tracer.set_attributes([
        {:"http.status_code", status},
        {:"http.response_duration_ms", duration_ms}
      ])

      if status >= 500 do
        Tracer.set_status(:error, "http #{status}")
      end

      Telemetry.http_request(conn.method, conn.request_path, status, duration)

      Observability.log(:info, "http_request_completed", %{
        request_id: conn.assigns.request_id,
        correlation_id: conn.assigns.correlation_id,
        trace_id: conn.assigns.trace_id,
        span_id: conn.assigns.span_id,
        method: conn.method,
        path: conn.request_path,
        status: status,
        duration_ms: duration_ms
      })

      Tracer.end_span()
      OpenTelemetry.Ctx.detach(conn.assigns.otel_ctx_token)
      conn
    end)
  end

  defp header(conn, name) do
    case get_req_header(conn, name) do
      [value | _rest] -> value
      _other -> nil
    end
  end

  defp maybe_put_traceparent_header(conn) do
    case Tracing.current_traceparent() do
      nil -> conn
      traceparent -> put_resp_header(conn, "traceparent", traceparent)
    end
  end
end
