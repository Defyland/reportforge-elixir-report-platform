defmodule ReportForgeWeb.Responses do
  @moduledoc false

  import Plug.Conn

  alias ReportForge

  def json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
  end

  # sobelow_skip ["XSS.SendResp"]
  def text(conn, status, content_type, body) do
    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("x-content-type-options", "nosniff")
    |> send_resp(status, body)
  end

  def error(conn, status, code, message, details \\ [], retryable \\ false) do
    json(conn, status, %{
      error: %{
        code: code,
        message: message,
        retryable: retryable,
        details: details
      },
      meta: meta(conn)
    })
  end

  def from_reason(conn, :not_found) do
    error(conn, 404, "not_found", "Requested resource was not found.")
  end

  def from_reason(conn, :unauthorized) do
    error(conn, 401, "unauthorized", "API key is missing or invalid.")
  end

  def from_reason(conn, :gone) do
    error(conn, 410, "artifact_expired", "The signed artifact URL has expired.", [], true)
  end

  def from_reason(conn, {:conflict, message}) do
    error(conn, 409, "conflict", message)
  end

  def from_reason(conn, {:bad_request, message}) do
    error(conn, 400, "bad_request", message)
  end

  def from_reason(conn, {:rate_limited, message}) do
    error(conn, 429, "rate_limited", message, [], true)
  end

  def from_reason(conn, {:validation_failed, details}) do
    error(conn, 422, "validation_failed", "Request body contains invalid fields.", details)
  end

  def meta(conn) do
    %{
      request_id: conn.assigns[:request_id],
      correlation_id: conn.assigns[:correlation_id],
      trace_id: conn.assigns[:trace_id],
      timestamp: ReportForge.utc_now() |> ReportForge.to_iso8601()
    }
  end
end
