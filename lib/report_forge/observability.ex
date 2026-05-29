defmodule ReportForge.Observability do
  @moduledoc false

  require Logger

  alias ReportForge
  alias ReportForge.Tracing

  def log(level, event, metadata \\ %{}) do
    payload =
      metadata
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(stringify_keys(Tracing.trace_metadata()))
      |> Map.merge(%{
        "event" => event,
        "service" => "reportforge-api",
        "timestamp" => ReportForge.utc_now() |> ReportForge.to_iso8601()
      })

    Logger.log(level, Jason.encode!(payload))
  end

  defp stringify_keys(metadata) do
    Map.new(metadata, fn {key, value} -> {to_string(key), value} end)
  end
end
