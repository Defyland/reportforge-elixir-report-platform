defmodule ReportForge.Repo.Migrations.AddAuditLogsAndCleanupSupport do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :string, primary_key: true
      add :organization_id, references(:organizations, type: :string, on_delete: :delete_all)
      add :actor_type, :string, null: false
      add :actor_id, :string
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :string
      add :outcome, :string, null: false
      add :request_id, :string
      add :correlation_id, :string
      add :trace_id, :string
      add :span_id, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:audit_logs, [:organization_id, :inserted_at])
    create index(:audit_logs, [:action, :inserted_at])
    create index(:reports, [:status, :completed_at, :failed_at, :cancelled_at])
  end
end
