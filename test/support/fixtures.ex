defmodule ReportForge.Fixtures do
  @moduledoc false

  import Plug.Conn

  alias ReportForge.{Identity, Reports}

  def organization_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    params =
      Map.merge(
        %{
          "name" => "Ledger Corp #{unique}",
          "slug" => "ledger-corp-#{unique}",
          "retention_days" => 30
        },
        attrs
      )

    {:ok, result} = Identity.register_organization(params)
    result
  end

  def report_fixture(organization, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    params =
      Map.merge(
        %{
          "template_name" => "cash_position",
          "format" => "csv",
          "requested_by" => "ops-#{unique}@example.com",
          "idempotency_key" => "idemp-#{unique}",
          "filters" => %{"row_limit" => 3}
        },
        attrs
      )

    {:ok, %{report: report}} = Reports.create_report(organization, params)
    report
  end

  def authenticate(conn, token) do
    put_req_header(conn, "x-api-key", token)
  end
end
