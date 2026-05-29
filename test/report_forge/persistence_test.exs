defmodule ReportForge.PersistenceTest do
  use ReportForge.DBCase, async: false

  @moduletag :db

  alias ReportForge
  alias ReportForge.Identity.{ApiKey, Organization}
  alias ReportForge.Persistence
  alias ReportForge.Repo
  alias ReportForge.Reports.Report

  test "registers an organization and bootstrap api key in one transaction" do
    org_id = ReportForge.generate_id("org")
    key_id = ReportForge.generate_id("key")

    attrs = %{
      id: org_id,
      name: "Treasury Ops",
      slug: "treasury-ops",
      retention_days: 45,
      api_key: %{
        id: key_id,
        name: "bootstrap",
        key_prefix: "bootstrap01",
        hashed_secret: ReportForge.sha256("super-secret-bootstrap-token"),
        token_hint: "oken"
      }
    }

    assert {:ok, %{organization: organization, api_key: api_key}} =
             Persistence.register_organization_with_bootstrap_key(attrs)

    assert organization.id == org_id
    assert api_key.organization_id == org_id
    assert Repo.aggregate(Organization, :count) == 1
    assert Repo.aggregate(ApiKey, :count) == 1
  end

  test "rolls back the organization transaction when the api key is invalid" do
    attrs = %{
      id: ReportForge.generate_id("org"),
      name: "Broken Org",
      slug: "broken-org",
      retention_days: 30,
      api_key: %{
        id: ReportForge.generate_id("key"),
        name: "x",
        key_prefix: "dup-key",
        hashed_secret: ReportForge.sha256("broken"),
        token_hint: "oken"
      }
    }

    assert {:error, changeset} = Persistence.register_organization_with_bootstrap_key(attrs)
    assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    assert Repo.aggregate(Organization, :count) == 0
    assert Repo.aggregate(ApiKey, :count) == 0
  end

  test "enforces report uniqueness and foreign key integrity" do
    organization = insert_organization()

    report_attrs = %{
      id: ReportForge.generate_id("rpt"),
      organization_id: organization.id,
      template_name: "cash_position",
      format: "csv",
      status: "queued",
      requested_by: "ops@example.com",
      filters: %{"row_limit" => 5},
      columns: ["as_of_date", "account_id"],
      idempotency_key: "dup-123",
      fingerprint: "fingerprint-123",
      correlation_id: "cor-123",
      progress_pct: 0,
      row_count: 0,
      byte_size: 0,
      attempt_count: 1
    }

    assert {:ok, report} = Persistence.insert_report(report_attrs)

    assert {:error, changeset} =
             Persistence.insert_report(%{
               report_attrs
               | id: ReportForge.generate_id("rpt"),
                 fingerprint: "fingerprint-456"
             })

    assert %{idempotency_key: ["has already been taken"]} = errors_on(changeset)

    assert {:error, invalid_event_changeset} =
             Persistence.insert_report_event(%{
               id: ReportForge.generate_id("evt"),
               report_id: ReportForge.generate_id("rpt"),
               event_type: "report.started",
               status: "running",
               progress_pct: 10,
               correlation_id: "cor-123",
               trace_id: sample_trace_id(),
               span_id: sample_span_id(),
               metadata: %{}
             })

    assert %{report_id: ["does not exist"]} = errors_on(invalid_event_changeset)
    assert report.organization_id == organization.id
  end

  test "stores ordered report events and a single artifact per report" do
    organization = insert_organization()
    report = insert_report(organization.id)

    assert {:ok, _event_one} =
             Persistence.insert_report_event(%{
               id: ReportForge.generate_id("evt"),
               report_id: report.id,
               event_type: "report.requested",
               status: "queued",
               progress_pct: 0,
               correlation_id: report.correlation_id,
               trace_id: sample_trace_id(),
               span_id: sample_span_id(),
               metadata: %{},
               inserted_at: ~U[2026-05-29 00:00:00.000000Z]
             })

    assert {:ok, _event_two} =
             Persistence.insert_report_event(%{
               id: ReportForge.generate_id("evt"),
               report_id: report.id,
               event_type: "report.completed",
               status: "succeeded",
               progress_pct: 100,
               correlation_id: report.correlation_id,
               trace_id: sample_trace_id(),
               span_id: "bbbbbbbbbbbbbbbb",
               metadata: %{},
               inserted_at: ~U[2026-05-29 00:01:00.000000Z]
             })

    assert ["report.requested", "report.completed"] ==
             report.id
             |> Persistence.list_report_events()
             |> Enum.map(& &1.event_type)

    artifact_attrs = %{
      id: ReportForge.generate_id("art"),
      organization_id: organization.id,
      report_id: report.id,
      token: "token-123",
      body: "csv-data",
      filename: "report.csv",
      content_type: "text/csv",
      expires_at: ~U[2026-05-30 00:00:00.000000Z]
    }

    assert {:ok, _artifact} = Persistence.insert_report_artifact(artifact_attrs)

    assert {:error, artifact_changeset} =
             Persistence.insert_report_artifact(%{
               artifact_attrs
               | id: ReportForge.generate_id("art"),
                 token: "token-456"
             })

    assert %{report_id: ["has already been taken"]} = errors_on(artifact_changeset)
  end

  defp insert_organization do
    {:ok, organization} =
      %Organization{}
      |> Organization.changeset(%{
        id: ReportForge.generate_id("org"),
        name: "Ops Finance",
        slug: "ops-finance-#{System.unique_integer([:positive])}",
        retention_days: 30
      })
      |> Repo.insert()

    organization
  end

  defp insert_report(organization_id) do
    {:ok, report} =
      %Report{}
      |> Report.changeset(%{
        id: ReportForge.generate_id("rpt"),
        organization_id: organization_id,
        template_name: "invoice_audit",
        format: "json",
        status: "queued",
        requested_by: "ops@example.com",
        filters: %{},
        columns: ["invoice_id"],
        fingerprint: "fp-#{System.unique_integer([:positive])}",
        correlation_id: "cor-#{System.unique_integer([:positive])}",
        progress_pct: 0,
        row_count: 0,
        byte_size: 0,
        attempt_count: 1
      })
      |> Repo.insert()

    report
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp sample_trace_id, do: "0123456789abcdef0123456789abcdef"
  defp sample_span_id, do: "aaaaaaaaaaaaaaaa"
end
