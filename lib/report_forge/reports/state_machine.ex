defmodule ReportForge.Reports.StateMachine do
  @moduledoc false

  @transitions %{
    "queued" => %{start: "running", cancel: "cancelled"},
    "running" => %{complete: "succeeded", fail: "failed", cancel: "cancelled"},
    "failed" => %{retry: "queued"},
    "cancelled" => %{retry: "queued"},
    "succeeded" => %{}
  }

  def transition(status, action) do
    case get_in(@transitions, [status, action]) do
      nil -> :error
      next_status -> {:ok, next_status}
    end
  end
end
