import Config

config :report_forge, ecto_repos: [ReportForge.Repo]

config :report_forge,
  artifact_storage_adapter: ReportForge.ArtifactStorage.Database,
  api_key_header: "x-api-key",
  base_url: "http://localhost:4000",
  report_ttl_seconds: 86_400,
  exporter_step_delay_ms: 15,
  default_row_limit: 25,
  max_row_limit: 500,
  public_write_limit: String.to_integer(System.get_env("REPORT_FORGE_PUBLIC_WRITE_LIMIT", "20")),
  tenant_read_limit: String.to_integer(System.get_env("REPORT_FORGE_TENANT_READ_LIMIT", "240")),
  tenant_write_limit: String.to_integer(System.get_env("REPORT_FORGE_TENANT_WRITE_LIMIT", "60"))

config :report_forge, ReportForge.Repo,
  username: System.get_env("REPORT_FORGE_DB_USER", "postgres"),
  password: System.get_env("REPORT_FORGE_DB_PASSWORD", "postgres"),
  hostname: System.get_env("REPORT_FORGE_DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("REPORT_FORGE_DB_PORT", "5432")),
  database: System.get_env("REPORT_FORGE_DB_NAME", "report_forge_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :report_forge, ReportForge.Oban,
  repo: ReportForge.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 86_400},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/30 * * * *", ReportForge.Maintenance.CleanupWorker,
        args: %{"task" => "purge_expired_artifacts"}},
       {"0 3 * * *", ReportForge.Maintenance.CleanupWorker,
        args: %{"task" => "purge_retained_reports"}}
     ]}
  ],
  queues: [reports: 10, maintenance: 2]

config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :correlation_id,
    :organization_id,
    :api_key_id,
    :report_id,
    :trace_id,
    :span_id
  ]

import_config "#{config_env()}.exs"
