defmodule ReportForge.Maintenance do
  @moduledoc false

  import Ecto.Query

  alias ReportForge.ArtifactStorage
  alias ReportForge.Identity.Organization
  alias ReportForge.Repo
  alias ReportForge.Reports.Report

  @terminal_statuses ["succeeded", "failed", "cancelled"]

  def purge_expired_artifacts(now \\ ReportForge.utc_now()) do
    report_ids = ArtifactStorage.expired_report_ids(now)

    report_update_count =
      case report_ids do
        [] ->
          0

        _ids ->
          {count, _rows} =
            Repo.update_all(
              from(report in Report, where: report.id in ^report_ids),
              set: [
                artifact_token: nil,
                artifact_filename: nil,
                artifact_content_type: nil,
                download_expires_at: nil,
                updated_at: now
              ]
            )

          count
      end

    artifact_delete_count = ArtifactStorage.delete_expired(now)

    %{
      artifact_delete_count: artifact_delete_count,
      report_update_count: report_update_count
    }
  end

  def purge_retained_reports(now \\ ReportForge.utc_now()) do
    report_ids =
      from(report in Report,
        join: organization in Organization,
        on: report.organization_id == organization.id,
        where: report.status in ^@terminal_statuses,
        select: %{
          id: report.id,
          completed_at: report.completed_at,
          failed_at: report.failed_at,
          cancelled_at: report.cancelled_at,
          inserted_at: report.inserted_at,
          retention_days: organization.retention_days
        }
      )
      |> Repo.all()
      |> Enum.filter(&stale_report?(&1, now))
      |> Enum.map(& &1.id)

    {report_delete_count, _rows} =
      case report_ids do
        [] ->
          {0, nil}

        _ids ->
          Repo.delete_all(from(report in Report, where: report.id in ^report_ids))
      end

    %{report_delete_count: report_delete_count}
  end

  def run_cleanup(now \\ ReportForge.utc_now()) do
    Repo.transaction(fn ->
      artifact_result = purge_expired_artifacts(now)
      report_result = purge_retained_reports(now)

      Map.merge(artifact_result, report_result)
    end)
  end

  defp stale_report?(report, now) do
    cutoff_at = DateTime.add(now, -report.retention_days * 86_400, :second)

    terminal_at =
      report.completed_at || report.failed_at || report.cancelled_at || report.inserted_at

    DateTime.compare(terminal_at, cutoff_at) != :gt
  end
end
