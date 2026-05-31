defmodule ReportForge.Release do
  @moduledoc false

  @app :report_forge

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _apps, _fun_return} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end

    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
