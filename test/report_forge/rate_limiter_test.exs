defmodule ReportForge.RateLimiterTest do
  use ExUnit.Case, async: false

  alias ReportForge.RateLimiter

  setup do
    original_max_buckets = Application.get_env(:report_forge, :rate_limit_max_buckets)

    RateLimiter.reset!()

    on_exit(fn ->
      if is_nil(original_max_buckets) do
        Application.delete_env(:report_forge, :rate_limit_max_buckets)
      else
        Application.put_env(:report_forge, :rate_limit_max_buckets, original_max_buckets)
      end

      RateLimiter.reset!()
    end)

    :ok
  end

  test "allows requests inside a bucket until the fixed-window limit is exceeded" do
    assert RateLimiter.allow?("tenant:read:org_123", 2, 60) == :ok
    assert RateLimiter.allow?("tenant:read:org_123", 2, 60) == :ok

    assert {:error, {:rate_limited, "rate limit exceeded for tenant:read:org_123"}} =
             RateLimiter.allow?("tenant:read:org_123", 2, 60)
  end

  test "rejects new buckets once configured capacity is reached" do
    Application.put_env(:report_forge, :rate_limit_max_buckets, 1)

    assert RateLimiter.allow?("tenant:read:org_123", 10, 60) == :ok
    assert RateLimiter.allow?("tenant:read:org_123", 10, 60) == :ok

    assert {:error, {:rate_limited, "rate limiter capacity exceeded"}} =
             RateLimiter.allow?("tenant:read:org_456", 10, 60)
  end

  test "serializes concurrent new-bucket admission against configured capacity" do
    Application.put_env(:report_forge, :rate_limit_max_buckets, 1)

    tasks =
      for index <- 1..32 do
        Task.async(fn ->
          receive do
            :go -> RateLimiter.allow?("tenant:read:org_#{index}", 10, 60)
          after
            1_000 -> flunk("concurrent admission test did not start")
          end
        end)
      end

    Enum.each(tasks, fn task -> send(task.pid, :go) end)
    results = Task.await_many(tasks, 5_000)

    assert Enum.count(results, &(&1 == :ok)) == 1

    assert Enum.count(
             results,
             &match?({:error, {:rate_limited, "rate limiter capacity exceeded"}}, &1)
           ) == 31
  end
end
