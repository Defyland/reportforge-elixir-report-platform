defmodule ReportForge.Repo.Migrations.AddTraceFieldsToReportEvents do
  use Ecto.Migration

  def change do
    alter table(:report_events) do
      add(:trace_id, :string)
      add(:span_id, :string)
    end
  end
end
