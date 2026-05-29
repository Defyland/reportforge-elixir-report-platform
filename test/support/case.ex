defmodule ReportForge.Case do
  @moduledoc false

  use ExUnit.CaseTemplate
  use Oban.Testing, repo: ReportForge.Repo

  alias Ecto.Adapters.SQL.Sandbox

  import Plug.Conn
  import Plug.Test

  using do
    quote do
      import Plug.Conn
      import Plug.Test
      import ReportForge.Case

      alias ReportForge.Fixtures
    end
  end

  setup tags do
    ReportForge.DBCase.ensure_repo_started()
    owner = Sandbox.start_owner!(ReportForge.Repo, shared: not tags[:async])

    on_exit(fn ->
      Sandbox.stop_owner(owner)
    end)

    ReportForge.Metrics.reset!()
    ReportForge.RateLimiter.reset!()
    :ok
  end

  def json_request(method, path, body \\ nil, headers \\ []) do
    encoded_body =
      cond do
        is_map(body) -> Jason.encode!(body)
        is_binary(body) -> body
        is_nil(body) -> ""
      end

    conn =
      conn(method, path, encoded_body)
      |> maybe_put_json_content_type(body)
      |> then(fn current_conn ->
        Enum.reduce(headers, current_conn, fn {name, value}, acc ->
          put_req_header(acc, name, value)
        end)
      end)

    ReportForgeWeb.Router.call(conn, ReportForgeWeb.Router.init([]))
  end

  def json_response(conn) do
    Jason.decode!(conn.resp_body)
  end

  def wait_until(fun, attempts \\ 60)

  def wait_until(_fun, 0),
    do: raise(ExUnit.AssertionError, message: "condition was not satisfied before timeout")

  def wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun, attempts - 1)
    end
  end

  defp maybe_put_json_content_type(conn, body) when is_map(body) do
    put_req_header(conn, "content-type", "application/json")
  end

  defp maybe_put_json_content_type(conn, _body), do: conn

  def drain_report_jobs(opts \\ []) do
    ReportForge.Oban.drain_queue(Keyword.merge([queue: :reports, with_recursion: true], opts))
  end

  def drain_maintenance_jobs(opts \\ []) do
    ReportForge.Oban.drain_queue(Keyword.merge([queue: :maintenance, with_recursion: true], opts))
  end
end
