defmodule ReportForge.Maintenance.CleanupWorkerTest do
  use ReportForge.Case, async: false

  import Ecto.Query

  alias ReportForge.Audit
  alias ReportForge.Maintenance.CleanupWorker
  alias ReportForge.Oban
  alias ReportForge.Repo
  alias ReportForge.Reports
  alias ReportForge.Reports.{Artifact, Report, ReportEvent}

  test "purges expired artifacts and clears report download metadata" do
    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"format" => "csv"})

    assert %{success: 1} = drain_report_jobs()

    expired_at = DateTime.add(ReportForge.utc_now(), -3_600, :second)

    Repo.update_all(
      from(artifact in Artifact, where: artifact.report_id == ^report.id),
      set: [expires_at: expired_at]
    )

    Repo.update_all(
      from(stored_report in Report, where: stored_report.id == ^report.id),
      set: [download_expires_at: expired_at]
    )

    assert {:ok, _job} =
             %{"task" => "purge_expired_artifacts"}
             |> CleanupWorker.new()
             |> Oban.insert()

    assert_enqueued(
      worker: CleanupWorker,
      queue: "maintenance",
      args: %{"task" => "purge_expired_artifacts"}
    )

    assert %{success: 1} = drain_maintenance_jobs()

    assert Repo.get_by(Artifact, report_id: report.id) == nil
    assert {:ok, cleaned_report} = Reports.get_report(organization, report.id)
    assert cleaned_report.artifact_token == nil
    assert cleaned_report.download_expires_at == nil

    assert Enum.any?(Audit.list_logs(), &(&1.action == "maintenance.purge_expired_artifacts"))
  end

  test "deletes terminal reports after the tenant retention window" do
    %{organization: organization} = Fixtures.organization_fixture(%{"retention_days" => 1})
    report = Fixtures.report_fixture(organization, %{"format" => "json"})

    assert %{success: 1} = drain_report_jobs()

    stale_at = DateTime.add(ReportForge.utc_now(), -172_800, :second)

    Repo.update_all(
      from(stored_report in Report, where: stored_report.id == ^report.id),
      set: [completed_at: stale_at, updated_at: stale_at]
    )

    assert {:ok, _job} =
             %{"task" => "purge_retained_reports"}
             |> CleanupWorker.new()
             |> Oban.insert()

    assert_enqueued(
      worker: CleanupWorker,
      queue: "maintenance",
      args: %{"task" => "purge_retained_reports"}
    )

    assert %{success: 1} = drain_maintenance_jobs()

    assert {:error, :not_found} = Reports.get_report(organization, report.id)

    assert Repo.aggregate(
             from(event in ReportEvent, where: event.report_id == ^report.id),
             :count
           ) == 0

    assert Repo.aggregate(
             from(artifact in Artifact, where: artifact.report_id == ^report.id),
             :count
           ) == 0

    assert Enum.any?(Audit.list_logs(), &(&1.action == "maintenance.purge_retained_reports"))
  end
end
