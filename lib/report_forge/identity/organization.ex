defmodule ReportForge.Identity.Organization do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ReportForge.Identity.ApiKey
  alias ReportForge.Reports.Report

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "organizations" do
    field(:name, :string)
    field(:slug, :string)
    field(:retention_days, :integer)

    has_many(:api_keys, ApiKey)
    has_many(:reports, Report)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:id, :name, :slug, :retention_days])
    |> validate_required([:id, :name, :slug, :retention_days])
    |> validate_length(:name, min: 3)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> validate_number(:retention_days, greater_than_or_equal_to: 1, less_than_or_equal_to: 365)
    |> unique_constraint(:slug)
  end
end
