import Config

if config_env() != :test do
  read_secret! = fn env_name, opts ->
    default = Keyword.get(opts, :default)
    file_env_name = "#{env_name}_FILE"

    cond do
      secret = System.get_env(env_name) ->
        secret

      secret_file = System.get_env(file_env_name) ->
        secret_file
        |> File.read!()
        |> String.trim()

      config_env() == :prod ->
        raise "#{env_name} or #{file_env_name} must be configured in production"

      true ->
        default
    end
  end

  port =
    System.get_env("PORT", "4000")
    |> String.to_integer()

  base_url = System.get_env("BASE_URL", "http://localhost:#{port}")
  signing_secret = read_secret!.("SIGNING_SECRET", default: "reportforge-dev-signing-secret")
  storage_adapter_name = System.get_env("REPORT_FORGE_ARTIFACT_STORAGE_ADAPTER", "local")
  repo_pool_size = String.to_integer(System.get_env("REPORT_FORGE_DB_POOL_SIZE", "10"))

  repo_config =
    case System.get_env("DATABASE_URL") do
      nil ->
        [
          username: System.get_env("REPORT_FORGE_DB_USER", "postgres"),
          password: System.get_env("REPORT_FORGE_DB_PASSWORD", "postgres"),
          hostname: System.get_env("REPORT_FORGE_DB_HOST", "127.0.0.1"),
          port: String.to_integer(System.get_env("REPORT_FORGE_DB_PORT", "5432")),
          database: System.get_env("REPORT_FORGE_DB_NAME", "report_forge_#{config_env()}"),
          pool_size: repo_pool_size
        ]

      database_url ->
        [
          url: database_url,
          pool_size: repo_pool_size
        ]
    end

  artifact_storage_adapter =
    case storage_adapter_name do
      "local" -> ReportForge.ArtifactStorage.Local
      "database" -> ReportForge.ArtifactStorage.Database
      "s3" -> ReportForge.ArtifactStorage.S3
      "minio" -> ReportForge.ArtifactStorage.S3
      other -> raise "unsupported REPORT_FORGE_ARTIFACT_STORAGE_ADAPTER=#{other}"
    end

  artifact_storage_path =
    System.get_env(
      "REPORT_FORGE_ARTIFACT_STORAGE_PATH",
      Path.join(System.tmp_dir!(), "report_forge_artifacts_#{config_env()}")
    )

  s3_region = System.get_env("REPORT_FORGE_S3_REGION", "us-east-1")
  s3_force_path_style_default = if storage_adapter_name == "minio", do: "true", else: "false"

  s3_secret_access_key =
    if artifact_storage_adapter == ReportForge.ArtifactStorage.S3 do
      read_secret!.("REPORT_FORGE_S3_SECRET_ACCESS_KEY", default: nil)
    else
      System.get_env("REPORT_FORGE_S3_SECRET_ACCESS_KEY")
    end

  artifact_storage_s3 = [
    access_key_id: System.get_env("REPORT_FORGE_S3_ACCESS_KEY_ID"),
    bucket: System.get_env("REPORT_FORGE_S3_BUCKET"),
    endpoint: System.get_env("REPORT_FORGE_S3_ENDPOINT", "https://s3.#{s3_region}.amazonaws.com"),
    force_path_style:
      System.get_env("REPORT_FORGE_S3_FORCE_PATH_STYLE", s3_force_path_style_default) == "true",
    presign_ttl_seconds:
      String.to_integer(System.get_env("REPORT_FORGE_S3_PRESIGN_TTL_SECONDS", "300")),
    public_endpoint: System.get_env("REPORT_FORGE_S3_PUBLIC_ENDPOINT"),
    region: s3_region,
    secret_access_key: s3_secret_access_key
  ]

  if config_env() == :prod and artifact_storage_adapter == ReportForge.ArtifactStorage.S3 do
    [:access_key_id, :bucket, :secret_access_key]
    |> Enum.each(fn key ->
      if is_nil(Keyword.fetch!(artifact_storage_s3, key)) do
        raise "REPORT_FORGE_S3_#{key |> Atom.to_string() |> String.upcase()} must be configured when S3 artifact storage is enabled in production"
      end
    end)
  end

  config :report_forge,
    http_port: port,
    base_url: base_url,
    artifact_storage_adapter: artifact_storage_adapter,
    artifact_storage_path: artifact_storage_path,
    artifact_storage_s3: artifact_storage_s3,
    signing_secret: signing_secret,
    server: System.get_env("PHX_SERVER", "true") != "false"

  config :report_forge,
         ReportForge.Repo,
         Keyword.merge(repo_config,
           stacktrace: config_env() == :dev,
           show_sensitive_data_on_connection_error: config_env() == :dev
         )
end
