defmodule ReportForgeWeb.OpenApiContractTest do
  use ReportForge.Case, async: false

  alias ReportForge.OpenApiContract

  test "validates operational endpoints and their client-error contract" do
    health_conn = json_request(:get, "/healthz")
    ready_conn = json_request(:get, "/readyz")
    metrics_conn = json_request(:get, "/metrics")

    assert health_conn.status == 200
    OpenApiContract.assert_response!(health_conn, "get", "/healthz")

    assert ready_conn.status == 200
    OpenApiContract.assert_response!(ready_conn, "get", "/readyz")

    assert metrics_conn.status == 200
    assert metrics_conn.resp_body =~ "reportforge_http_requests_total"

    Enum.each(["/healthz", "/readyz", "/metrics"], fn path ->
      OpenApiContract.assert_operation_has_4xx!("get", path)
    end)
  end

  test "validates primary JSON responses against openapi schemas" do
    create_org_conn =
      json_request(:post, "/api/v1/organizations", %{
        "organization" => %{
          "name" => "Contract Labs",
          "slug" => "contract-labs",
          "retention_days" => 30
        }
      })

    assert create_org_conn.status == 201
    OpenApiContract.assert_response!(create_org_conn, "post", "/api/v1/organizations")

    token = get_in(json_response(create_org_conn), ["data", "bootstrap_api_key"])

    create_report_conn =
      json_request(
        :post,
        "/api/v1/reports",
        %{
          "report" => %{
            "template_name" => "cash_position",
            "format" => "csv",
            "requested_by" => "contracts@example.com",
            "idempotency_key" => "contract-report-1",
            "filters" => %{"row_limit" => 2}
          }
        },
        [{"x-api-key", token}]
      )

    assert create_report_conn.status == 202
    OpenApiContract.assert_response!(create_report_conn, "post", "/api/v1/reports")

    report_id = get_in(json_response(create_report_conn), ["data", "id"])
    assert %{success: 1} = drain_report_jobs()

    get_report_conn =
      json_request(:get, "/api/v1/reports/#{report_id}", nil, [{"x-api-key", token}])

    assert get_report_conn.status == 200
    OpenApiContract.assert_response!(get_report_conn, "get", "/api/v1/reports/{id}")

    list_reports_conn = json_request(:get, "/api/v1/reports", nil, [{"x-api-key", token}])
    assert list_reports_conn.status == 200
    OpenApiContract.assert_response!(list_reports_conn, "get", "/api/v1/reports")

    events_conn =
      json_request(:get, "/api/v1/reports/#{report_id}/events", nil, [{"x-api-key", token}])

    assert events_conn.status == 200
    OpenApiContract.assert_response!(events_conn, "get", "/api/v1/reports/{id}/events")

    download_conn =
      json_request(:get, "/api/v1/reports/#{report_id}/download", nil, [{"x-api-key", token}])

    assert download_conn.status == 200
    OpenApiContract.assert_response!(download_conn, "get", "/api/v1/reports/{id}/download")
  end

  test "validates error responses against openapi schemas" do
    %{bootstrap_api_key: token} = Fixtures.organization_fixture()

    conn =
      json_request(
        :post,
        "/api/v1/reports",
        %{"report" => %{"template_name" => "cash_position", "format" => "xml"}},
        [{"x-api-key", token}]
      )

    assert conn.status == 422
    OpenApiContract.assert_response!(conn, "post", "/api/v1/reports")
  end
end
