defmodule ReportForge.ArtifactStorage.S3 do
  @moduledoc false

  @behaviour ReportForge.ArtifactStorage

  import Ecto.Query

  alias ReportForge
  alias ReportForge.ArtifactStorage.Key
  alias ReportForge.Repo
  alias ReportForge.Reports.Artifact
  alias ReportForge.Signing

  @empty_body_hash ReportForge.sha256("")
  @service "s3"

  @impl ReportForge.ArtifactStorage
  def put_artifact(%{body: body} = attrs) when is_binary(body) do
    storage_key = Key.build(attrs)
    checksum = ReportForge.sha256(body)

    with {:ok, config} <- config(),
         :ok <- put_object(config, storage_key, attrs, body, checksum) do
      case insert_metadata(attrs, storage_key, body, checksum) do
        {:ok, artifact} ->
          {:ok, artifact}

        {:error, %Ecto.Changeset{} = changeset} ->
          _ = delete_object(config, storage_key)
          {:error, changeset}
      end
    else
      {:error, reason} ->
        {:error, {"storage_unavailable", storage_error(reason)}}
    end
  end

  @impl ReportForge.ArtifactStorage
  def fetch_artifact(nil), do: {:error, :conflict}

  def fetch_artifact(token) do
    case Repo.get_by(Artifact, token: token) do
      nil ->
        {:error, :not_found}

      artifact ->
        if Signing.expired?(artifact.expires_at) do
          {:error, :gone}
        else
          {:ok, artifact}
        end
    end
  end

  @impl ReportForge.ArtifactStorage
  def open_artifact(%Artifact{storage_key: storage_key} = artifact) when is_binary(storage_key) do
    with {:ok, config} <- config() do
      {:ok, {:redirect, presigned_get_url(config, storage_key, artifact)}}
    else
      {:error, reason} -> {:error, {"storage_unavailable", storage_error(reason)}}
    end
  end

  def open_artifact(%Artifact{body: body}) when is_binary(body), do: {:ok, {:binary, body}}
  def open_artifact(%Artifact{}), do: {:error, :not_found}

  @impl ReportForge.ArtifactStorage
  def delete_for_report(report_id) do
    artifacts = Repo.all(from(artifact in Artifact, where: artifact.report_id == ^report_id))

    {count, _rows} =
      Repo.delete_all(from(artifact in Artifact, where: artifact.report_id == ^report_id))

    Enum.each(artifacts, &delete_remote_object/1)
    count
  end

  @impl ReportForge.ArtifactStorage
  def expired_report_ids(now) do
    now
    |> expired_query()
    |> select([artifact], artifact.report_id)
    |> Repo.all()
  end

  @impl ReportForge.ArtifactStorage
  def delete_expired(now) do
    artifacts = Repo.all(expired_query(now))
    {count, _rows} = Repo.delete_all(expired_query(now))
    Enum.each(artifacts, &delete_remote_object/1)
    count
  end

  defp insert_metadata(attrs, storage_key, body, checksum) do
    attrs =
      attrs
      |> Map.delete(:body)
      |> Map.merge(%{
        storage_key: storage_key,
        byte_size: byte_size(body),
        checksum: checksum
      })

    %Artifact{} |> Artifact.changeset(attrs) |> Repo.insert()
  end

  defp put_object(config, storage_key, attrs, body, checksum) do
    headers = [
      {"content-type", Map.fetch!(attrs, :content_type)},
      {"x-amz-meta-checksum", checksum}
    ]

    request = signed_request(:put, config, storage_key, headers, body)

    case config.http_client.request(:put, request.url, request.headers, body) do
      {:ok, %{status: status}} when status >= 200 and status <= 299 ->
        :ok

      {:ok, %{status: status, body: response_body}} ->
        {:error, {:s3_status, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_object(config, storage_key) do
    request = signed_request(:delete, config, storage_key, [], "")

    case config.http_client.request(:delete, request.url, request.headers, "") do
      {:ok, %{status: status}} when status >= 200 and status <= 299 ->
        :ok

      {:ok, %{status: status, body: response_body}} ->
        {:error, {:s3_status, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_remote_object(%Artifact{storage_key: storage_key}) when is_binary(storage_key) do
    with {:ok, config} <- config() do
      _ = delete_object(config, storage_key)
    end

    :ok
  end

  defp delete_remote_object(%Artifact{}), do: :ok

  defp presigned_get_url(config, storage_key, artifact) do
    now = DateTime.utc_now()
    date = date_stamp(now)
    amz_date = amz_date(now)
    scope = credential_scope(date, config.region)
    endpoint = object_endpoint(config, storage_key)

    query_params = [
      {"X-Amz-Algorithm", "AWS4-HMAC-SHA256"},
      {"X-Amz-Credential", "#{config.access_key_id}/#{scope}"},
      {"X-Amz-Date", amz_date},
      {"X-Amz-Expires", Integer.to_string(config.presign_ttl_seconds)},
      {"X-Amz-SignedHeaders", "host"},
      {"response-content-disposition", "attachment; filename=\"#{artifact.filename}\""},
      {"response-content-type", artifact.content_type}
    ]

    canonical_query = canonical_query(query_params)

    canonical_request =
      [
        "GET",
        endpoint.path,
        canonical_query,
        "host:#{endpoint.host_header}\n",
        "host",
        "UNSIGNED-PAYLOAD"
      ]
      |> Enum.join("\n")

    string_to_sign = string_to_sign(amz_date, scope, canonical_request)
    signature = sign(config.secret_access_key, date, config.region, string_to_sign)

    endpoint
    |> Map.fetch!(:uri)
    |> Map.put(:query, "#{canonical_query}&X-Amz-Signature=#{signature}")
    |> URI.to_string()
  end

  defp signed_request(method, config, storage_key, headers, body) do
    now = DateTime.utc_now()
    date = date_stamp(now)
    amz_date = amz_date(now)
    body_hash = if method == :put, do: ReportForge.sha256(body), else: @empty_body_hash
    endpoint = object_endpoint(config, storage_key)

    headers =
      headers
      |> normalize_headers()
      |> Map.merge(%{
        "host" => endpoint.host_header,
        "x-amz-content-sha256" => body_hash,
        "x-amz-date" => amz_date
      })

    {canonical_headers, signed_headers} = canonical_headers(headers)

    canonical_request =
      [
        method |> Atom.to_string() |> String.upcase(),
        endpoint.path,
        "",
        canonical_headers,
        signed_headers,
        body_hash
      ]
      |> Enum.join("\n")

    scope = credential_scope(date, config.region)
    string_to_sign = string_to_sign(amz_date, scope, canonical_request)
    signature = sign(config.secret_access_key, date, config.region, string_to_sign)

    authorization =
      "AWS4-HMAC-SHA256 Credential=#{config.access_key_id}/#{scope}, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    headers =
      headers
      |> Map.put("authorization", authorization)
      |> Enum.sort_by(fn {name, _value} -> name end)

    %{url: URI.to_string(endpoint.uri), headers: headers}
  end

  defp object_endpoint(config, storage_key) do
    endpoint = URI.parse(config.endpoint)
    scheme = endpoint.scheme || "https"
    port = endpoint.port
    host = endpoint.host || raise ArgumentError, "S3 endpoint host is required"
    base_segments = endpoint.path |> to_string() |> String.split("/", trim: true)
    key_segments = String.split(storage_key, "/", trim: true)

    {host, path_segments} =
      if config.force_path_style do
        {host, base_segments ++ [config.bucket] ++ key_segments}
      else
        {"#{config.bucket}.#{host}", base_segments ++ key_segments}
      end

    uri = %URI{
      scheme: scheme,
      host: host,
      port: port,
      path: "/" <> Enum.map_join(path_segments, "/", &aws_encode/1)
    }

    %{uri: uri, path: uri.path, host_header: host_header(uri)}
  end

  defp host_header(%URI{scheme: "https", port: 443, host: host}), do: host
  defp host_header(%URI{scheme: "http", port: 80, host: host}), do: host
  defp host_header(%URI{host: host, port: nil}), do: host
  defp host_header(%URI{host: host, port: port}), do: "#{host}:#{port}"

  defp canonical_headers(headers) do
    headers = Enum.sort_by(headers, fn {name, _value} -> name end)

    canonical =
      Enum.map_join(headers, fn {name, value} ->
        "#{name}:#{normalize_header_value(value)}\n"
      end)

    signed =
      Enum.map_join(headers, ";", fn {name, _value} -> name end)

    {canonical, signed}
  end

  defp canonical_query(params) do
    params
    |> Enum.map(fn {key, value} -> {aws_encode(key), aws_encode(value)} end)
    |> Enum.sort()
    |> Enum.map_join("&", fn {key, value} -> "#{key}=#{value}" end)
  end

  defp normalize_headers(headers) do
    Map.new(headers, fn {name, value} ->
      {name |> to_string() |> String.downcase(), to_string(value)}
    end)
  end

  defp normalize_header_value(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp string_to_sign(amz_date, scope, canonical_request) do
    [
      "AWS4-HMAC-SHA256",
      amz_date,
      scope,
      ReportForge.sha256(canonical_request)
    ]
    |> Enum.join("\n")
  end

  defp credential_scope(date, region), do: "#{date}/#{region}/#{@service}/aws4_request"

  defp sign(secret, date, region, string_to_sign) do
    ("AWS4" <> secret)
    |> hmac(date)
    |> hmac(region)
    |> hmac(@service)
    |> hmac("aws4_request")
    |> hmac(string_to_sign)
    |> Base.encode16(case: :lower)
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)

  defp date_stamp(%DateTime{} = now), do: Calendar.strftime(now, "%Y%m%d")
  defp amz_date(%DateTime{} = now), do: Calendar.strftime(now, "%Y%m%dT%H%M%SZ")

  defp aws_encode(value), do: value |> to_string() |> URI.encode(&URI.char_unreserved?/1)

  defp expired_query(now), do: from(artifact in Artifact, where: artifact.expires_at <= ^now)

  defp config do
    raw = Application.get_env(:report_forge, :artifact_storage_s3, [])

    config = %{
      access_key_id: get_config(raw, :access_key_id),
      bucket: get_config(raw, :bucket),
      endpoint: get_config(raw, :endpoint, "https://s3.amazonaws.com"),
      force_path_style: get_config(raw, :force_path_style, false),
      http_client: get_config(raw, :http_client, ReportForge.ArtifactStorage.S3HTTPClient),
      presign_ttl_seconds: get_config(raw, :presign_ttl_seconds, 300),
      region: get_config(raw, :region, "us-east-1"),
      secret_access_key: get_config(raw, :secret_access_key)
    }

    missing =
      [:access_key_id, :bucket, :secret_access_key]
      |> Enum.filter(fn key -> blank?(Map.fetch!(config, key)) end)

    if missing == [] do
      {:ok, config}
    else
      {:error, {:missing_s3_config, missing}}
    end
  end

  defp get_config(config, key, default \\ nil) do
    cond do
      Keyword.keyword?(config) -> Keyword.get(config, key, default)
      is_map(config) -> Map.get(config, key, default)
      true -> default
    end
  end

  defp blank?(value), do: is_nil(value) or value == ""

  defp storage_error({:missing_s3_config, keys}) do
    "missing S3 artifact storage configuration: #{Enum.join(keys, ", ")}"
  end

  defp storage_error({:s3_status, status, response_body}) do
    "S3 responded with status #{status}: #{response_excerpt(response_body)}"
  end

  defp storage_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp storage_error(reason), do: inspect(reason)

  defp response_excerpt(body) when is_binary(body), do: String.slice(body, 0, 200)
  defp response_excerpt(body), do: inspect(body)
end
