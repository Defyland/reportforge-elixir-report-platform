defmodule ReportForge.RateLimiter do
  @moduledoc false

  use Agent

  alias ReportForge

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def reset! do
    Agent.update(__MODULE__, fn _state -> %{} end)
  end

  def allow?(bucket, limit, window_seconds) when is_binary(bucket) do
    now = ReportForge.utc_now()

    Agent.get_and_update(__MODULE__, fn state ->
      key = {bucket, window_seconds}

      entry = current_window_entry(Map.get(state, key), now, window_seconds)

      if entry.count >= limit do
        {{:error, {:rate_limited, "rate limit exceeded for #{bucket}"}}, state}
      else
        updated_entry = %{entry | count: entry.count + 1}
        {:ok, Map.put(state, key, updated_entry)}
      end
    end)
  end

  defp current_window_entry(%{reset_at: reset_at} = existing, now, window_seconds) do
    if DateTime.compare(reset_at, now) == :gt do
      existing
    else
      %{count: 0, reset_at: DateTime.add(now, window_seconds, :second)}
    end
  end

  defp current_window_entry(_expired_or_missing, now, window_seconds) do
    %{count: 0, reset_at: DateTime.add(now, window_seconds, :second)}
  end
end
