defmodule ReportForge.Signing do
  @moduledoc false

  alias Plug.Crypto.MessageVerifier
  alias ReportForge

  def sign_download(payload) when is_map(payload) do
    payload
    |> Jason.encode!()
    |> MessageVerifier.sign(secret())
  end

  def verify_download(token) when is_binary(token) do
    case MessageVerifier.verify(token, secret()) do
      {:ok, payload} ->
        Jason.decode(payload)

      :error ->
        {:error, :invalid_signature}
    end
  end

  def download_url(token) do
    base_url = Application.fetch_env!(:report_forge, :base_url)
    "#{base_url}/downloads/#{URI.encode_www_form(token)}"
  end

  def expired?(expires_at) do
    DateTime.compare(expires_at, ReportForge.utc_now()) != :gt
  end

  defp secret do
    Application.fetch_env!(:report_forge, :signing_secret)
  end
end
