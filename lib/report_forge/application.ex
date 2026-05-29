defmodule ReportForge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ReportForge.Repo,
        ReportForge.Oban,
        ReportForge.Metrics,
        ReportForge.RateLimiter
      ] ++ maybe_http_server()

    Supervisor.start_link(children, strategy: :one_for_one, name: ReportForge.Supervisor)
  end

  defp maybe_http_server do
    if Application.get_env(:report_forge, :server, true) do
      [
        {Bandit,
         plug: ReportForgeWeb.Router,
         scheme: :http,
         port: Application.get_env(:report_forge, :http_port, 4000)}
      ]
    else
      []
    end
  end
end
