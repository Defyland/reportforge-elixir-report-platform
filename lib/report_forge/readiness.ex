defmodule ReportForge.Readiness do
  @moduledoc false

  defmodule Checker do
    @moduledoc false

    @callback database_status() :: :up | {:down, String.t()}
    @callback oban_status() :: :up | {:down, String.t()}
    @callback signer_status() :: :up | {:down, String.t()}
  end

  defmodule DefaultChecker do
    @moduledoc false

    @behaviour ReportForge.Readiness.Checker

    alias ReportForge.Repo

    @impl true
    def database_status do
      case Repo.query("SELECT 1") do
        {:ok, _result} -> :up
        {:error, _exception} -> {:down, "query_failed"}
      end
    rescue
      _exception -> {:down, "query_failed"}
    end

    @impl true
    def oban_status do
      case Oban.whereis(ReportForge.Oban) do
        pid when is_pid(pid) ->
          if Process.alive?(pid), do: :up, else: {:down, "supervisor_unavailable"}

        _other ->
          {:down, "supervisor_unavailable"}
      end
    end

    @impl true
    def signer_status do
      case Application.get_env(:report_forge, :signing_secret) do
        secret when is_binary(secret) and secret != "" -> :up
        _other -> {:down, "missing_signing_secret"}
      end
    end
  end

  def status do
    checker = checker()

    checks = %{
      database: check_to_string(checker.database_status()),
      oban: check_to_string(checker.oban_status()),
      signer: check_to_string(checker.signer_status())
    }

    ready? = Enum.all?(checks, fn {_name, value} -> value == "up" end)

    %{
      ready?: ready?,
      status: if(ready?, do: "ready", else: "not_ready"),
      checks: checks
    }
  end

  defp checker do
    Application.get_env(:report_forge, :readiness_checker, DefaultChecker)
  end

  defp check_to_string(:up), do: "up"
  defp check_to_string({:down, reason}), do: "down: #{reason}"
end
