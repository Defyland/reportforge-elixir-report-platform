defmodule ReportForgeWeb.RouterTest do
  use ReportForge.Case, async: false

  test "rejects authenticated endpoints without an api key" do
    conn =
      json_request(:post, "/api/v1/reports", %{"report" => %{"template_name" => "cash_position"}})

    assert conn.status == 401
    assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn)
  end

  test "serves health, readiness, and metrics endpoints" do
    health_conn = json_request(:get, "/healthz")
    ready_conn = json_request(:get, "/readyz")
    metrics_conn = json_request(:get, "/metrics")

    assert health_conn.status == 200
    assert get_in(json_response(health_conn), ["status"]) == "ok"
    assert get_resp_header(health_conn, "traceparent") != []

    assert ready_conn.status == 200
    assert get_in(json_response(ready_conn), ["checks", "oban"]) == "up"

    assert metrics_conn.status == 200
    assert metrics_conn.resp_body =~ "reportforge_http_requests_total"
  end

  test "creates an organization, creates a report, and exposes report events" do
    create_org_conn =
      json_request(:post, "/api/v1/organizations", %{
        "organization" => %{
          "name" => "Treasury Labs",
          "slug" => "treasury-labs",
          "retention_days" => 45
        }
      })

    assert create_org_conn.status == 201
    assert get_resp_header(create_org_conn, "traceparent") != []

    %{
      "data" => %{
        "organization" => %{"id" => organization_id},
        "bootstrap_api_key" => token
      },
      "meta" => %{"trace_id" => create_org_trace_id}
    } = json_response(create_org_conn)

    assert is_binary(create_org_trace_id)

    report_conn =
      json_request(
        :post,
        "/api/v1/reports",
        %{
          "report" => %{
            "template_name" => "invoice_audit",
            "format" => "json",
            "requested_by" => "analyst@example.com",
            "idempotency_key" => "report-001",
            "filters" => %{"row_limit" => 3}
          }
        },
        [{"x-api-key", token}]
      )

    assert report_conn.status == 202

    %{
      "data" => %{"id" => report_id},
      "meta" => %{"deduplicated" => false, "trace_id" => report_trace_id}
    } =
      json_response(report_conn)

    assert is_binary(report_trace_id)

    assert %{success: 1} = drain_report_jobs()

    wait_until(fn ->
      report = json_request(:get, "/api/v1/reports/#{report_id}", nil, [{"x-api-key", token}])
      report.status == 200 and get_in(json_response(report), ["data", "status"]) == "succeeded"
    end)

    org_conn = json_request(:get, "/api/v1/organizations/me", nil, [{"x-api-key", token}])
    assert org_conn.status == 200
    assert get_in(json_response(org_conn), ["data", "id"]) == organization_id

    events_conn =
      json_request(:get, "/api/v1/reports/#{report_id}/events", nil, [{"x-api-key", token}])

    assert events_conn.status == 200

    assert Enum.any?(
             json_response(events_conn)["data"],
             &(&1["event_type"] == "report.completed")
           )

    trace_ids =
      events_conn
      |> json_response()
      |> Map.fetch!("data")
      |> Enum.map(& &1["trace_id"])
      |> Enum.uniq()

    assert trace_ids == [report_trace_id]
  end

  test "hides reports from other tenants" do
    first_tenant = Fixtures.organization_fixture()
    second_tenant = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(first_tenant.organization)

    conn =
      json_request(:get, "/api/v1/reports/#{report.id}", nil, [
        {"x-api-key", second_tenant.bootstrap_api_key}
      ])

    assert conn.status == 404
    assert %{"error" => %{"code" => "not_found"}} = json_response(conn)
  end

  test "serves report artifacts through signed download urls" do
    %{organization: organization, bootstrap_api_key: token} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"format" => "csv"})

    assert %{success: 1} = drain_report_jobs()

    download_conn =
      json_request(:get, "/api/v1/reports/#{report.id}/download", nil, [{"x-api-key", token}])

    assert download_conn.status == 200
    download_url = get_in(json_response(download_conn), ["data", "url"])
    path = URI.parse(download_url).path

    artifact_conn = json_request(:get, path)
    assert artifact_conn.status == 200
    assert artifact_conn.resp_body =~ "as_of_date"
  end

  test "returns validation errors for unsupported report formats" do
    %{bootstrap_api_key: token} = Fixtures.organization_fixture()

    conn =
      json_request(
        :post,
        "/api/v1/reports",
        %{
          "report" => %{
            "template_name" => "cash_position",
            "format" => "xml",
            "requested_by" => "ops@example.com"
          }
        },
        [{"x-api-key", token}]
      )

    assert conn.status == 422
    assert %{"error" => %{"code" => "validation_failed"}} = json_response(conn)
  end

  test "rate limits repeated organization creation when the public limit is exceeded" do
    original_limit = Application.get_env(:report_forge, :public_write_limit)
    Application.put_env(:report_forge, :public_write_limit, 1)
    on_exit(fn -> Application.put_env(:report_forge, :public_write_limit, original_limit) end)

    first_conn =
      json_request(:post, "/api/v1/organizations", %{
        "organization" => %{
          "name" => "Org One",
          "slug" => "org-one",
          "retention_days" => 30
        }
      })

    second_conn =
      json_request(:post, "/api/v1/organizations", %{
        "organization" => %{
          "name" => "Org Two",
          "slug" => "org-two",
          "retention_days" => 30
        }
      })

    assert first_conn.status == 201
    assert second_conn.status == 429
    assert %{"error" => %{"code" => "rate_limited"}} = json_response(second_conn)
  end

  test "manages api keys and report listings through authenticated routes" do
    %{organization: organization, bootstrap_api_key: token} = Fixtures.organization_fixture()
    _report = Fixtures.report_fixture(organization, %{"format" => "json"})

    list_api_keys_conn = json_request(:get, "/api/v1/api-keys", nil, [{"x-api-key", token}])
    assert list_api_keys_conn.status == 200
    assert length(json_response(list_api_keys_conn)["data"]) == 1

    create_api_key_conn =
      json_request(
        :post,
        "/api/v1/api-keys",
        %{"api_key" => %{"name" => "analytics"}},
        [{"x-api-key", token}]
      )

    assert create_api_key_conn.status == 201
    issued_key_id = get_in(json_response(create_api_key_conn), ["data", "api_key", "id"])
    issued_token = get_in(json_response(create_api_key_conn), ["data", "token"])

    list_reports_conn = json_request(:get, "/api/v1/reports", nil, [{"x-api-key", token}])
    assert list_reports_conn.status == 200
    assert length(json_response(list_reports_conn)["data"]) == 1

    revoke_api_key_conn =
      json_request(:delete, "/api/v1/api-keys/#{issued_key_id}", nil, [{"x-api-key", token}])

    assert revoke_api_key_conn.status == 200

    unauthorized_conn =
      json_request(:get, "/api/v1/organizations/me", nil, [{"x-api-key", issued_token}])

    assert unauthorized_conn.status == 401
  end
end
