defmodule ReportForge.AuditTest do
  use ReportForge.Case, async: false

  alias ReportForge.Audit
  alias ReportForge.Identity
  alias ReportForge.Reports

  test "persists audit records for tenant bootstrap and api key management" do
    %{organization: organization} = Fixtures.organization_fixture()

    [bootstrap_log] = Audit.list_logs(organization.id)
    assert bootstrap_log.action == "organization.registered"
    assert bootstrap_log.resource_id == organization.id

    assert {:ok, %{api_key: api_key}} =
             Identity.issue_api_key(organization, %{"name" => "analytics"})

    assert {:ok, _revoked_key} = Identity.revoke_api_key(organization, api_key.id)

    actions =
      organization.id
      |> Audit.list_logs()
      |> Enum.map(& &1.action)

    assert actions == [
             "organization.registered",
             "api_key.issued",
             "api_key.revoked"
           ]
  end

  test "persists audit records for report creation, retries, and downloads" do
    original_delay = Application.get_env(:report_forge, :exporter_step_delay_ms)
    Application.put_env(:report_forge, :exporter_step_delay_ms, 50)
    on_exit(fn -> Application.put_env(:report_forge, :exporter_step_delay_ms, original_delay) end)

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"filters" => %{"row_limit" => 10}})

    drainer = Task.async(fn -> drain_report_jobs() end)

    wait_until(fn ->
      match?({:ok, %{status: "running"}}, Reports.get_report(organization, report.id))
    end)

    assert {:ok, _cancelled_report} = Reports.cancel_report(organization, report.id)
    drain_result = Task.await(drainer, 5_000)
    assert drain_result.success + drain_result.cancelled == 1

    assert {:ok, queued_report} = Reports.retry_report(organization, report.id)
    assert queued_report.attempt_count == 2
    assert %{success: 1} = drain_report_jobs()

    assert {:ok, download_link} = Reports.get_download_link(organization, report.id)

    token =
      download_link.url
      |> URI.parse()
      |> Map.fetch!(:path)
      |> String.replace_prefix("/downloads/", "")
      |> URI.decode_www_form()

    assert {:ok, _artifact} = Reports.download_artifact(token)

    actions =
      organization.id
      |> Audit.list_logs()
      |> Enum.map(& &1.action)

    assert actions == [
             "organization.registered",
             "report.requested",
             "report.cancelled",
             "report.retry_requested",
             "report.download_link_resolved",
             "report.artifact_downloaded"
           ]
  end
end
