import Config

config :report_forge,
  server: false,
  exporter_step_delay_ms: 0,
  signing_secret: "reportforge-test-signing-secret",
  artifact_storage_path: Path.join(System.tmp_dir!(), "report_forge_artifacts_test")

config :opentelemetry, traces_exporter: :none

config :report_forge, ReportForge.Oban,
  repo: ReportForge.Repo,
  plugins: false,
  queues: [reports: 10, maintenance: 2],
  testing: :manual

config :report_forge, ReportForge.Repo,
  username: System.get_env("REPORT_FORGE_DB_USER", "postgres"),
  password: System.get_env("REPORT_FORGE_DB_PASSWORD", "postgres"),
  hostname: System.get_env("REPORT_FORGE_DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("REPORT_FORGE_DB_PORT", "5432")),
  database: System.get_env("REPORT_FORGE_DB_NAME", "report_forge_test"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
