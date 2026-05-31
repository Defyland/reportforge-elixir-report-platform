defmodule ReportForge.Repo.Migrations.ScopeReportFingerprintDedupeToActiveReports do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(:reports, [:organization_id, :fingerprint], name: :reports_org_fingerprint_index)
    )

    create unique_index(:reports, [:organization_id, :fingerprint],
             name: :reports_org_fingerprint_index,
             where: "status IN ('queued', 'running', 'succeeded')"
           )
  end
end
