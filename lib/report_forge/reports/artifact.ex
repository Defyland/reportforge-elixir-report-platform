defmodule ReportForge.Reports.Artifact do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ReportForge.Identity.Organization
  alias ReportForge.Reports.Report

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "report_artifacts" do
    field(:token, :string)
    field(:body, :binary)
    field(:filename, :string)
    field(:content_type, :string)
    field(:expires_at, :utc_datetime_usec)

    belongs_to(:organization, Organization)
    belongs_to(:report, Report)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :id,
      :organization_id,
      :report_id,
      :token,
      :body,
      :filename,
      :content_type,
      :expires_at,
      :inserted_at
    ])
    |> validate_required([
      :id,
      :organization_id,
      :report_id,
      :token,
      :body,
      :filename,
      :content_type,
      :expires_at
    ])
    |> unique_constraint(:token)
    |> unique_constraint(:report_id, name: :report_artifacts_report_id_index)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:report_id)
  end
end
