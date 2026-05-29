defmodule ReportForge.Audit.Log do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ReportForge.Identity.Organization

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "audit_logs" do
    field(:actor_type, :string)
    field(:actor_id, :string)
    field(:action, :string)
    field(:resource_type, :string)
    field(:resource_id, :string)
    field(:outcome, :string)
    field(:request_id, :string)
    field(:correlation_id, :string)
    field(:trace_id, :string)
    field(:span_id, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:organization, Organization)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :id,
      :organization_id,
      :actor_type,
      :actor_id,
      :action,
      :resource_type,
      :resource_id,
      :outcome,
      :request_id,
      :correlation_id,
      :trace_id,
      :span_id,
      :metadata,
      :inserted_at
    ])
    |> validate_required([
      :id,
      :actor_type,
      :action,
      :resource_type,
      :outcome,
      :metadata
    ])
    |> foreign_key_constraint(:organization_id)
  end
end
