defmodule ReportForge.Reports.Report do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ReportForge.Identity.Organization
  alias ReportForge.Reports.{Artifact, ReportEvent}

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "reports" do
    field(:template_name, :string)
    field(:format, :string)
    field(:status, :string)
    field(:requested_by, :string)
    field(:filters, :map, default: %{})
    field(:columns, {:array, :string}, default: [])
    field(:idempotency_key, :string)
    field(:fingerprint, :string)
    field(:correlation_id, :string)
    field(:progress_pct, :integer, default: 0)
    field(:row_count, :integer, default: 0)
    field(:byte_size, :integer, default: 0)
    field(:checksum, :string)
    field(:attempt_count, :integer, default: 1)
    field(:execution_job_id, :integer)
    field(:artifact_token, :string)
    field(:artifact_filename, :string)
    field(:artifact_content_type, :string)
    field(:download_expires_at, :utc_datetime_usec)
    field(:started_at, :utc_datetime_usec)
    field(:completed_at, :utc_datetime_usec)
    field(:failed_at, :utc_datetime_usec)
    field(:cancelled_at, :utc_datetime_usec)
    field(:last_error_code, :string)
    field(:last_error, :string)

    belongs_to(:organization, Organization)
    has_many(:events, ReportEvent)
    has_one(:artifact, Artifact)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :id,
      :organization_id,
      :template_name,
      :format,
      :status,
      :requested_by,
      :filters,
      :columns,
      :idempotency_key,
      :fingerprint,
      :correlation_id,
      :progress_pct,
      :row_count,
      :byte_size,
      :checksum,
      :attempt_count,
      :execution_job_id,
      :artifact_token,
      :artifact_filename,
      :artifact_content_type,
      :download_expires_at,
      :started_at,
      :completed_at,
      :failed_at,
      :cancelled_at,
      :last_error_code,
      :last_error
    ])
    |> validate_required([
      :id,
      :organization_id,
      :template_name,
      :format,
      :status,
      :requested_by,
      :filters,
      :columns,
      :fingerprint,
      :correlation_id,
      :progress_pct,
      :row_count,
      :byte_size,
      :attempt_count
    ])
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint(:idempotency_key, name: :reports_org_idempotency_key_index)
    |> unique_constraint(:fingerprint, name: :reports_org_fingerprint_index)
  end
end
