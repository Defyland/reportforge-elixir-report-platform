defmodule ReportForgeWeb.Router do
  use Plug.Router

  import Plug.Conn

  alias ReportForge.Identity
  alias ReportForge.Metrics
  alias ReportForge.RateLimiter
  alias ReportForge.Readiness
  alias ReportForge.Reports
  alias ReportForgeWeb.{Auth, Payloads, RequestContext, Responses}

  plug(RequestContext)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  get "/healthz" do
    Responses.json(conn, 200, %{
      status: "ok",
      service: "reportforge-api",
      timestamp: Responses.meta(conn).timestamp
    })
  end

  get "/readyz" do
    readiness = Readiness.status()
    http_status = if(readiness.ready?, do: 200, else: 503)

    Responses.json(conn, http_status, %{
      status: readiness.status,
      service: "reportforge-api",
      checks: readiness.checks,
      timestamp: Responses.meta(conn).timestamp
    })
  end

  get "/metrics" do
    Responses.text(conn, 200, "text/plain; version=0.0.4", Metrics.render_prometheus())
  end

  post "/api/v1/organizations" do
    with :ok <- public_rate_limit(conn),
         %{"organization" => organization_params} <- conn.body_params,
         {:ok, result} <- Identity.register_organization(organization_params) do
      Responses.json(conn, 201, %{
        data: %{
          organization: Payloads.organization(result.organization),
          bootstrap_api_key: result.bootstrap_api_key,
          api_key: Payloads.api_key(result.api_key)
        },
        meta: Responses.meta(conn)
      })
    else
      :error ->
        Responses.from_reason(
          conn,
          {:bad_request, "request body must contain an organization object"}
        )

      {:error, reason} ->
        Responses.from_reason(conn, reason)
    end
  end

  get "/api/v1/organizations/me" do
    with_auth(conn, :read, fn conn, organization, _api_key ->
      Responses.json(conn, 200, %{
        data: Payloads.organization(organization),
        meta: Responses.meta(conn)
      })
    end)
  end

  get "/api/v1/api-keys" do
    with_auth(conn, :read, fn conn, organization, _api_key ->
      api_keys = Identity.list_api_keys(organization)

      Responses.json(conn, 200, %{
        data: Enum.map(api_keys, &Payloads.api_key/1),
        meta: Responses.meta(conn)
      })
    end)
  end

  post "/api/v1/api-keys" do
    with_auth(conn, :write, fn conn, organization, _api_key ->
      with %{"api_key" => api_key_params} <- conn.body_params,
           {:ok, result} <- Identity.issue_api_key(organization, api_key_params) do
        Responses.json(conn, 201, %{
          data: %{
            api_key: Payloads.api_key(result.api_key),
            token: result.token
          },
          meta: Responses.meta(conn)
        })
      else
        :error ->
          Responses.from_reason(
            conn,
            {:bad_request, "request body must contain an api_key object"}
          )

        {:error, reason} ->
          Responses.from_reason(conn, reason)
      end
    end)
  end

  delete "/api/v1/api-keys/:id" do
    with_auth(conn, :write, fn conn, organization, _api_key ->
      with {:ok, api_key} <- Identity.revoke_api_key(organization, id) do
        Responses.json(conn, 200, %{data: Payloads.api_key(api_key), meta: Responses.meta(conn)})
      else
        {:error, reason} -> Responses.from_reason(conn, reason)
      end
    end)
  end

  get "/api/v1/reports" do
    with_auth(conn, :read, fn conn, organization, _api_key ->
      reports = Reports.list_reports(organization, conn.params)

      Responses.json(conn, 200, %{
        data: Enum.map(reports, &Payloads.report/1),
        meta: Responses.meta(conn)
      })
    end)
  end

  post "/api/v1/reports" do
    with_auth(conn, :write, fn conn, organization, _api_key ->
      with %{"report" => report_params} <- conn.body_params,
           {:ok, %{report: report, deduplicated?: deduplicated?}} <-
             Reports.create_report(organization, report_params) do
        status = if(deduplicated?, do: 200, else: 202)

        Responses.json(conn, status, %{
          data: Payloads.report(report),
          meta: Map.put(Responses.meta(conn), :deduplicated, deduplicated?)
        })
      else
        :error ->
          Responses.from_reason(conn, {:bad_request, "request body must contain a report object"})

        {:error, reason} ->
          Responses.from_reason(conn, reason)
      end
    end)
  end

  get "/api/v1/reports/:id" do
    with_auth(conn, :read, fn conn, organization, _api_key ->
      with {:ok, report} <- Reports.get_report(organization, id) do
        Responses.json(conn, 200, %{data: Payloads.report(report), meta: Responses.meta(conn)})
      else
        {:error, reason} -> Responses.from_reason(conn, reason)
      end
    end)
  end

  get "/api/v1/reports/:id/events" do
    with_auth(conn, :read, fn conn, organization, _api_key ->
      with {:ok, report_events} <- Reports.list_report_events(organization, id) do
        Responses.json(conn, 200, %{
          data: Enum.map(report_events, &Payloads.event/1),
          meta: Responses.meta(conn)
        })
      else
        {:error, reason} -> Responses.from_reason(conn, reason)
      end
    end)
  end

  get "/api/v1/reports/:id/download" do
    with_auth(conn, :read, fn conn, organization, _api_key ->
      with {:ok, download_link} <- Reports.get_download_link(organization, id) do
        Responses.json(conn, 200, %{data: download_link, meta: Responses.meta(conn)})
      else
        {:error, reason} -> Responses.from_reason(conn, reason)
      end
    end)
  end

  post "/api/v1/reports/:id/cancel" do
    with_auth(conn, :write, fn conn, organization, _api_key ->
      with {:ok, report} <- Reports.cancel_report(organization, id) do
        Responses.json(conn, 200, %{data: Payloads.report(report), meta: Responses.meta(conn)})
      else
        {:error, reason} -> Responses.from_reason(conn, reason)
      end
    end)
  end

  post "/api/v1/reports/:id/retry" do
    with_auth(conn, :write, fn conn, organization, _api_key ->
      with {:ok, report} <- Reports.retry_report(organization, id) do
        Responses.json(conn, 200, %{data: Payloads.report(report), meta: Responses.meta(conn)})
      else
        {:error, reason} -> Responses.from_reason(conn, reason)
      end
    end)
  end

  get "/downloads/:token" do
    case Reports.download_artifact(token) do
      {:ok, %{artifact: artifact, source: source}} ->
        send_artifact(conn, artifact, source)

      {:error, reason} ->
        Responses.from_reason(conn, reason)
    end
  end

  match _ do
    Responses.from_reason(conn, :not_found)
  end

  defp with_auth(conn, access_mode, callback) do
    case Auth.authenticate(conn) do
      {:ok, organization, api_key} ->
        with :ok <- tenant_rate_limit(organization.id, access_mode) do
          Logger.metadata(organization_id: organization.id, api_key_id: api_key.id)
          callback.(conn, organization, api_key)
        else
          {:error, reason} -> Responses.from_reason(conn, reason)
        end

      {:error, reason} ->
        Responses.from_reason(conn, reason)
    end
  end

  defp public_rate_limit(conn) do
    bucket = "public:#{client_ip(conn)}"
    RateLimiter.allow?(bucket, Application.get_env(:report_forge, :public_write_limit, 20), 60)
  end

  defp tenant_rate_limit(organization_id, :read) do
    RateLimiter.allow?(
      "tenant:#{organization_id}:read",
      Application.get_env(:report_forge, :tenant_read_limit, 240),
      60
    )
  end

  defp tenant_rate_limit(organization_id, :write) do
    RateLimiter.allow?(
      "tenant:#{organization_id}:write",
      Application.get_env(:report_forge, :tenant_write_limit, 60),
      60
    )
  end

  defp client_ip(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp put_artifact_headers(conn, artifact) do
    conn
    |> put_resp_header("content-type", artifact.content_type)
    |> put_resp_header("content-disposition", "attachment; filename=\"#{artifact.filename}\"")
    |> put_resp_header("cache-control", "private, max-age=60")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  # sobelow_skip ["Traversal.SendFile"]
  defp send_artifact(conn, artifact, {:file, path}) do
    conn = put_artifact_headers(conn, artifact)
    send_file(conn, 200, path)
  end

  # sobelow_skip ["XSS.SendResp"]
  defp send_artifact(conn, artifact, {:binary, body}) do
    conn = put_artifact_headers(conn, artifact)
    send_resp(conn, 200, body)
  end

  defp send_artifact(conn, _artifact, {:redirect, url}) do
    conn
    |> put_resp_header("location", url)
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(302, "")
  end
end
