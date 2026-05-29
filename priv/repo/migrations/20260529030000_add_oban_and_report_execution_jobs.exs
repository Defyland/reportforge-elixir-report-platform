defmodule ReportForge.Repo.Migrations.AddObanAndReportExecutionJobs do
  use Ecto.Migration

  def up do
    Oban.Migrations.up()

    alter table(:reports) do
      add(:execution_job_id, :integer)
    end
  end

  def down do
    alter table(:reports) do
      remove(:execution_job_id)
    end

    Oban.Migrations.down(version: Oban.Migration.current_version())
  end
end
