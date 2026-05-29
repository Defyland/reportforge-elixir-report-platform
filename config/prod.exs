import Config

config :report_forge,
  server: true

config :report_forge, ReportForge.Repo,
  stacktrace: false,
  show_sensitive_data_on_connection_error: false,
  pool_size: String.to_integer(System.get_env("REPORT_FORGE_DB_POOL_SIZE", "10"))

config :logger, level: :info
