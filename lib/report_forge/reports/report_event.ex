defmodule ReportForge.Reports.ReportEvent do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ReportForge.Reports.Report

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "report_events" do
    field(:event_type, :string)
    field(:status, :string)
    field(:progress_pct, :integer)
    field(:correlation_id, :string)
    field(:trace_id, :string)
    field(:span_id, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:report, Report)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(report_event, attrs) do
    report_event
    |> cast(attrs, [
      :id,
      :report_id,
      :event_type,
      :status,
      :progress_pct,
      :correlation_id,
      :trace_id,
      :span_id,
      :metadata,
      :inserted_at
    ])
    |> validate_required([
      :id,
      :report_id,
      :event_type,
      :status,
      :progress_pct,
      :correlation_id,
      :trace_id,
      :span_id,
      :metadata
    ])
    |> foreign_key_constraint(:report_id)
  end
end
