defmodule ReportForge.MixProject do
  use Mix.Project

  def project do
    [
      app: :report_forge,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [summary: [threshold: 75]],
      deps: deps(),
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  def application do
    [
      mod: {ReportForge.Application, []},
      extra_applications: [
        :crypto,
        :inets,
        :logger,
        :runtime_tools,
        :ssl,
        :opentelemetry_exporter,
        :opentelemetry
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:plug, "~> 1.15"},
      {:plug_crypto, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:oban, "~> 2.17"},
      {:opentelemetry, "~> 1.6"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.9"},
      {:telemetry, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "sobelow --skip --exit",
        "deps.audit",
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "test --cover"
      ]
    ]
  end
end
