defmodule ReportForgeWeb.Auth do
  @moduledoc false

  import Plug.Conn

  alias ReportForge.Identity

  def authenticate(conn) do
    header = Application.get_env(:report_forge, :api_key_header, "x-api-key")

    case get_req_header(conn, header) do
      [token | _rest] -> Identity.authenticate_api_key(token)
      _other -> {:error, :unauthorized}
    end
  end
end
