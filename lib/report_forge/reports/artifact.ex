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
    field(:storage_key, :string)
    field(:filename, :string)
    field(:content_type, :string)
    field(:byte_size, :integer)
    field(:checksum, :string)
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
      :storage_key,
      :filename,
      :content_type,
      :byte_size,
      :checksum,
      :expires_at,
      :inserted_at
    ])
    |> validate_required([
      :id,
      :organization_id,
      :report_id,
      :token,
      :filename,
      :content_type,
      :expires_at
    ])
    |> validate_artifact_payload()
    |> unique_constraint(:token)
    |> unique_constraint(:report_id, name: :report_artifacts_report_id_index)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:report_id)
  end

  defp validate_artifact_payload(changeset) do
    body = get_field(changeset, :body)
    storage_key = get_field(changeset, :storage_key)

    if present?(body) or present?(storage_key) do
      changeset
    else
      add_error(changeset, :storage_key, "or body must be present")
    end
  end

  defp present?(value) when is_binary(value), do: value != ""
  defp present?(value), do: not is_nil(value)
end
