defmodule ReportForge.Repo do
  use Ecto.Repo,
    otp_app: :report_forge,
    adapter: Ecto.Adapters.Postgres
end
