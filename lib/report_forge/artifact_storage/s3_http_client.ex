defmodule ReportForge.ArtifactStorage.S3HTTPClient do
  @moduledoc false

  @callback request(atom(), String.t(), [{String.t(), String.t()}], binary()) ::
              {:ok, %{status: non_neg_integer(), body: binary()}} | {:error, term()}

  def request(method, url, headers, body \\ "") do
    headers = Enum.map(headers, fn {name, value} -> {to_charlist(name), to_charlist(value)} end)

    request =
      if method in [:put, :post] do
        {to_charlist(url), headers, content_type(headers), body}
      else
        {to_charlist(url), headers}
      end

    case :httpc.request(method, request, http_options(), body_format: :binary) do
      {:ok, {{_version, status, _reason}, _headers, response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp content_type(headers) do
    headers
    |> Enum.find_value(~c"application/octet-stream", fn {name, value} ->
      if String.downcase(to_string(name)) == "content-type", do: value
    end)
  end

  defp http_options do
    [
      timeout: Application.get_env(:report_forge, :artifact_storage_s3_timeout_ms, 15_000),
      connect_timeout:
        Application.get_env(:report_forge, :artifact_storage_s3_connect_timeout_ms, 5_000)
    ]
  end
end
