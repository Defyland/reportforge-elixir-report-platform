defmodule ReportForge.DBCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias ReportForge.Repo

  using do
    quote do
      alias ReportForge.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ReportForge.DBCase
    end
  end

  setup tags do
    ensure_repo_started()
    owner = Sandbox.start_owner!(Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(owner) end)
    :ok
  end

  def ensure_repo_started do
    case Process.whereis(Repo) do
      nil ->
        {:ok, _pid} = Repo.start_link()

      _pid ->
        :ok
    end
  end
end
