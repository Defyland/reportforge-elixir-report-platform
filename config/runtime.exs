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

  artifact_storage_path =
    System.get_env(
      "REPORT_FORGE_ARTIFACT_STORAGE_PATH",
      Path.join(System.tmp_dir!(), "report_forge_artifacts_#{config_env()}")
    )

  config :report_forge,
    http_port: port,
    base_url: base_url,
    artifact_storage_path: artifact_storage_path,
    signing_secret: signing_secret,
    server: System.get_env("PHX_SERVER", "true") != "false"
end
