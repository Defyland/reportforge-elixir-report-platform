defmodule ReportForge.Tracing do
  @moduledoc false

  require OpenTelemetry.Tracer, as: Tracer

  def current_context do
    OpenTelemetry.Ctx.get_current()
  end

  def current_carrier do
    inject_context(current_context())
  end

  def inject_context(nil), do: %{}

  def inject_context(context) do
    context
    |> :otel_propagator_text_map.inject_from([])
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  def attach_context(nil), do: :ok

  def attach_context(context) do
    OpenTelemetry.Ctx.attach(context)
    :ok
  end

  def context_from_carrier(carrier) when carrier in [nil, %{}], do: nil

  def context_from_carrier(carrier) when is_map(carrier) do
    carrier
    |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
    |> then(&:otel_propagator_text_map.extract_to(OpenTelemetry.Ctx.new(), &1))
  end

  def trace_metadata do
    case Tracer.current_span_ctx() do
      span_ctx when not is_nil(span_ctx) and span_ctx != :undefined ->
        if :otel_span.is_valid(span_ctx) do
          %{
            trace_id: to_string(:otel_span.hex_trace_id(span_ctx)),
            span_id: to_string(:otel_span.hex_span_id(span_ctx))
          }
        else
          %{}
        end

      _other ->
        %{}
    end
  end

  def current_trace_id do
    trace_metadata()[:trace_id]
  end

  def current_span_id do
    trace_metadata()[:span_id]
  end

  def current_traceparent do
    case Tracer.current_span_ctx() do
      span_ctx when not is_nil(span_ctx) and span_ctx != :undefined ->
        if :otel_span.is_valid(span_ctx) do
          hex_span_ctx = :otel_span.hex_span_ctx(span_ctx)

          "00-#{to_string(hex_span_ctx.otel_trace_id)}-#{to_string(hex_span_ctx.otel_span_id)}-#{to_string(hex_span_ctx.otel_trace_flags)}"
        end

      _other ->
        nil
    end
  end
end
