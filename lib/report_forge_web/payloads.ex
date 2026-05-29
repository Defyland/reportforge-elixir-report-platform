defmodule ReportForgeWeb.Payloads do
  @moduledoc false

  alias ReportForge
  alias ReportForge.Identity.{ApiKey, Organization}
  alias ReportForge.Reports.{Report, ReportEvent}
  alias ReportForge.Signing

  def organization(%Organization{} = organization) do
    %{
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      retention_days: organization.retention_days,
      inserted_at: ReportForge.to_iso8601(organization.inserted_at),
      updated_at: ReportForge.to_iso8601(organization.updated_at)
    }
  end

  def api_key(%ApiKey{} = api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      key_prefix: api_key.key_prefix,
      token_hint: api_key.token_hint,
      last_used_at: ReportForge.to_iso8601(api_key.last_used_at),
      revoked_at: ReportForge.to_iso8601(api_key.revoked_at),
      inserted_at: ReportForge.to_iso8601(api_key.inserted_at),
      updated_at: ReportForge.to_iso8601(api_key.updated_at)
    }
  end

  def report(%Report{} = report) do
    %{
      id: report.id,
      template_name: report.template_name,
      format: report.format,
      status: report.status,
      requested_by: report.requested_by,
      filters: report.filters,
      columns: report.columns,
      idempotency_key: report.idempotency_key,
      fingerprint: report.fingerprint,
      correlation_id: report.correlation_id,
      progress_pct: report.progress_pct,
      row_count: report.row_count,
      byte_size: report.byte_size,
      checksum: report.checksum,
      attempt_count: report.attempt_count,
      artifact: artifact_payload(report),
      error: error_payload(report),
      inserted_at: ReportForge.to_iso8601(report.inserted_at),
      updated_at: ReportForge.to_iso8601(report.updated_at),
      started_at: ReportForge.to_iso8601(report.started_at),
      completed_at: ReportForge.to_iso8601(report.completed_at),
      failed_at: ReportForge.to_iso8601(report.failed_at),
      cancelled_at: ReportForge.to_iso8601(report.cancelled_at)
    }
  end

  def event(%ReportEvent{} = report_event) do
    %{
      id: report_event.id,
      report_id: report_event.report_id,
      event_type: report_event.event_type,
      status: report_event.status,
      progress_pct: report_event.progress_pct,
      correlation_id: report_event.correlation_id,
      trace_id: report_event.trace_id,
      span_id: report_event.span_id,
      metadata: report_event.metadata,
      inserted_at: ReportForge.to_iso8601(report_event.inserted_at)
    }
  end

  defp artifact_payload(%Report{artifact_token: nil}), do: nil

  defp artifact_payload(%Report{} = report) do
    %{
      filename: report.artifact_filename,
      content_type: report.artifact_content_type,
      download_url: Signing.download_url(report.artifact_token),
      expires_at: ReportForge.to_iso8601(report.download_expires_at)
    }
  end

  defp error_payload(%Report{last_error_code: nil}), do: nil

  defp error_payload(%Report{} = report) do
    %{
      code: report.last_error_code,
      message: report.last_error
    }
  end
end
