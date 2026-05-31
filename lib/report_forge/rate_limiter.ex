defmodule ReportForge.RateLimiter do
  @moduledoc false

  use GenServer

  @table __MODULE__
  @default_max_buckets 50_000
  @prune_interval_ms 60_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_prune()

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:prune_expired, state) do
    prune_expired(System.system_time(:second))
    schedule_prune()

    {:noreply, state}
  end

  def reset! do
    if table_ready?() do
      :ets.delete_all_objects(@table)
    end

    :ok
  end

  def allow?(bucket, limit, window_seconds) when is_binary(bucket) do
    ensure_table!()

    now = System.system_time(:second)
    key = {bucket, window_seconds}

    with :ok <- enforce_capacity(key) do
      allow_in_window(key, bucket, limit, now, now + window_seconds)
    end
  end

  defp allow_in_window(key, bucket, limit, now, next_reset_at) do
    case :ets.lookup(@table, key) do
      [] ->
        true = :ets.insert(@table, {key, 0, next_reset_at})
        increment_bucket(key, bucket, limit)

      [{^key, _count, reset_at}] when reset_at <= now ->
        true = :ets.insert(@table, {key, 0, next_reset_at})
        increment_bucket(key, bucket, limit)

      [{^key, _count, _reset_at}] ->
        increment_bucket(key, bucket, limit)
    end
  end

  defp increment_bucket(key, bucket, limit) do
    count = :ets.update_counter(@table, key, {2, 1})

    if count <= limit do
      :ok
    else
      {:error, {:rate_limited, "rate limit exceeded for #{bucket}"}}
    end
  end

  defp enforce_capacity(key) do
    if :ets.member(@table, key) do
      :ok
    else
      enforce_new_bucket_capacity()
    end
  end

  defp enforce_new_bucket_capacity do
    max_buckets =
      Application.get_env(:report_forge, :rate_limit_max_buckets, @default_max_buckets)

    case :ets.info(@table, :size) do
      size when is_integer(size) and size < max_buckets ->
        :ok

      _too_large ->
        prune_expired(System.system_time(:second))

        if :ets.info(@table, :size) < max_buckets do
          :ok
        else
          {:error, {:rate_limited, "rate limiter capacity exceeded"}}
        end
    end
  end

  defp prune_expired(now) do
    :ets.select_delete(@table, [
      {{:_, :_, :"$1"}, [{:"=<", :"$1", now}], [true]}
    ])
  end

  defp ensure_table! do
    unless table_ready?() do
      case start_link([]) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, reason} -> raise "rate limiter unavailable: #{inspect(reason)}"
      end
    end
  end

  defp table_ready?, do: :ets.whereis(@table) != :undefined

  defp schedule_prune do
    Process.send_after(self(), :prune_expired, @prune_interval_ms)
  end
end
