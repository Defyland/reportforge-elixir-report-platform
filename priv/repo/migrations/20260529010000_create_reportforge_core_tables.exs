defmodule ReportForge.Repo.Migrations.CreateReportforgeCoreTables do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :retention_days, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organizations, [:slug])

    create table(:api_keys, primary_key: false) do
      add :id, :string, primary_key: true
      add :organization_id, references(:organizations, type: :string, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :key_prefix, :string, null: false
      add :hashed_secret, :string, null: false
      add :token_hint, :string, null: false
      add :last_used_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_keys, [:key_prefix])
    create index(:api_keys, [:organization_id, :inserted_at])

    create table(:reports, primary_key: false) do
      add :id, :string, primary_key: true
      add :organization_id, references(:organizations, type: :string, on_delete: :delete_all), null: false
      add :template_name, :string, null: false
      add :format, :string, null: false
      add :status, :string, null: false
      add :requested_by, :string, null: false
      add :filters, :map, null: false, default: %{}
      add :columns, {:array, :string}, null: false, default: []
      add :idempotency_key, :string
      add :fingerprint, :string, null: false
      add :correlation_id, :string, null: false
      add :progress_pct, :integer, null: false, default: 0
      add :row_count, :integer, null: false, default: 0
      add :byte_size, :integer, null: false, default: 0
      add :checksum, :string
      add :attempt_count, :integer, null: false, default: 1
      add :artifact_token, :string
      add :artifact_filename, :string
      add :artifact_content_type, :string
      add :download_expires_at, :utc_datetime_usec
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :last_error_code, :string
      add :last_error, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:reports, [:organization_id, :idempotency_key], name: :reports_org_idempotency_key_index, where: "idempotency_key IS NOT NULL")
    create unique_index(:reports, [:organization_id, :fingerprint], name: :reports_org_fingerprint_index)
    create index(:reports, [:organization_id, :status, :inserted_at])

    create table(:report_events, primary_key: false) do
      add :id, :string, primary_key: true
      add :report_id, references(:reports, type: :string, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :status, :string, null: false
      add :progress_pct, :integer, null: false
      add :correlation_id, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:report_events, [:report_id, :inserted_at])

    create table(:report_artifacts, primary_key: false) do
      add :id, :string, primary_key: true
      add :organization_id, references(:organizations, type: :string, on_delete: :delete_all), null: false
      add :report_id, references(:reports, type: :string, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :body, :binary, null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:report_artifacts, [:token])
    create unique_index(:report_artifacts, [:report_id])
    create index(:report_artifacts, [:organization_id, :expires_at])
  end
end
