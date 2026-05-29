defmodule ReportForge.Reports.Generator do
  @moduledoc false

  alias ReportForge
  alias ReportForge.Reports.Report

  @templates %{
    "cash_position" => %{
      columns: [
        "as_of_date",
        "account_id",
        "currency",
        "available_balance_cents",
        "pending_debit_cents",
        "pending_credit_cents"
      ]
    },
    "ledger_summary" => %{
      columns: [
        "period_start",
        "period_end",
        "ledger_code",
        "entry_count",
        "debit_cents",
        "credit_cents",
        "net_cents"
      ]
    },
    "invoice_audit" => %{
      columns: [
        "invoice_id",
        "customer_id",
        "status",
        "issue_date",
        "due_date",
        "amount_cents",
        "currency"
      ]
    }
  }

  @formats ~w(csv json zip)

  def templates, do: Map.keys(@templates)
  def formats, do: @formats

  def normalize_request(attrs) when is_map(attrs) do
    template_name = read_string(attrs, "template_name")
    format = read_string(attrs, "format")
    requested_by = read_string(attrs, "requested_by")
    idempotency_key = read_string(attrs, "idempotency_key")
    correlation_id = read_string(attrs, "correlation_id")
    filters = read_filters(attrs)
    normalized_filters = normalize_filters(filters)
    details = validation_details(template_name, format, requested_by, filters, normalized_filters)

    if details == [] do
      {:ok,
       %{
         template_name: template_name,
         format: format,
         requested_by: requested_by,
         idempotency_key: idempotency_key,
         correlation_id: correlation_id || ReportForge.generate_id("cor"),
         filters: normalized_filters,
         columns: @templates[template_name].columns
       }}
    else
      {:error, {:validation_failed, details}}
    end
  end

  def normalize_request(_attrs) do
    {:error, {:validation_failed, [%{field: "report", issue: "must be an object"}]}}
  end

  def fingerprint(organization_id, normalized_attrs) do
    %{
      organization_id: organization_id,
      template_name: normalized_attrs.template_name,
      format: normalized_attrs.format,
      filters: normalized_attrs.filters
    }
    |> ReportForge.stable_json()
    |> ReportForge.sha256()
  end

  def generate(%Report{} = report) do
    case Map.get(report.filters, "simulate_failure") do
      "source_timeout" ->
        {:error, {"source_timeout", "upstream warehouse query timed out"}}

      "storage_unavailable" ->
        {:error, {"storage_unavailable", "object storage upload failed"}}

      _other ->
        rows = build_rows(report.template_name, report.filters)
        manifest = build_manifest(report, rows)
        build_artifact(report, rows, manifest)
    end
  end

  defp build_rows(template_name, filters) do
    row_limit = Map.fetch!(filters, "row_limit")

    Enum.map(1..row_limit, fn index ->
      case template_name do
        "cash_position" -> cash_position_row(index, filters)
        "ledger_summary" -> ledger_summary_row(index, filters)
        "invoice_audit" -> invoice_audit_row(index, filters)
      end
    end)
  end

  defp cash_position_row(index, filters) do
    %{
      "as_of_date" => Map.get(filters, "as_of_date", "2026-05-28"),
      "account_id" => "acct_#{1000 + index}",
      "currency" => Map.get(filters, "currency", "USD"),
      "available_balance_cents" => 125_000 + index * 750,
      "pending_debit_cents" => rem(index * 1_800, 15_000),
      "pending_credit_cents" => rem(index * 2_400, 18_000)
    }
  end

  defp ledger_summary_row(index, filters) do
    debits = 35_000 + index * 1_200
    credits = 27_500 + index * 900

    %{
      "period_start" => Map.get(filters, "period_start", "2026-05-01"),
      "period_end" => Map.get(filters, "period_end", "2026-05-28"),
      "ledger_code" => "GL-#{100 + rem(index, 18)}",
      "entry_count" => 10 + rem(index * 3, 55),
      "debit_cents" => debits,
      "credit_cents" => credits,
      "net_cents" => debits - credits
    }
  end

  defp invoice_audit_row(index, filters) do
    %{
      "invoice_id" => "inv_#{2_000 + index}",
      "customer_id" => "cus_#{500 + rem(index, 40)}",
      "status" => Enum.at(["issued", "paid", "overdue"], rem(index, 3)),
      "issue_date" => Map.get(filters, "issue_date", "2026-05-01"),
      "due_date" => Map.get(filters, "due_date", "2026-06-01"),
      "amount_cents" => 15_000 + index * 315,
      "currency" => Map.get(filters, "currency", "USD")
    }
  end

  defp build_manifest(report, rows) do
    %{
      "report_id" => report.id,
      "template_name" => report.template_name,
      "format" => report.format,
      "requested_by" => report.requested_by,
      "row_count" => length(rows),
      "generated_at" => ReportForge.utc_now() |> ReportForge.to_iso8601()
    }
  end

  defp build_artifact(%Report{format: "csv"} = report, rows, manifest) do
    body = render_csv(report.columns, rows)

    {:ok,
     %{
       body: body,
       row_count: length(rows),
       byte_size: byte_size(body),
       checksum: ReportForge.sha256(body),
       filename: filename(report, "csv"),
       content_type: "text/csv",
       manifest: manifest
     }}
  end

  defp build_artifact(%Report{format: "json"} = report, rows, manifest) do
    body = Jason.encode!(%{"manifest" => manifest, "rows" => rows})

    {:ok,
     %{
       body: body,
       row_count: length(rows),
       byte_size: byte_size(body),
       checksum: ReportForge.sha256(body),
       filename: filename(report, "json"),
       content_type: "application/json",
       manifest: manifest
     }}
  end

  defp build_artifact(%Report{format: "zip"} = report, rows, manifest) do
    csv_body = render_csv(report.columns, rows)
    json_body = Jason.encode!(%{"manifest" => manifest, "rows" => rows})
    manifest_body = Jason.encode!(manifest)

    {:ok, {_archive_name, body}} =
      :zip.create(
        ~c"report_bundle.zip",
        [
          {~c"manifest.json", manifest_body},
          {~c"report.csv", csv_body},
          {~c"report.json", json_body}
        ],
        [:memory]
      )

    {:ok,
     %{
       body: body,
       row_count: length(rows),
       byte_size: byte_size(body),
       checksum: ReportForge.sha256(body),
       filename: filename(report, "zip"),
       content_type: "application/zip",
       manifest: manifest
     }}
  end

  defp filename(report, extension) do
    timestamp = report.inserted_at |> DateTime.to_unix()
    "#{report.template_name}-#{timestamp}.#{extension}"
  end

  defp render_csv(columns, rows) do
    header = Enum.join(columns, ",")

    body =
      Enum.map_join(rows, "\n", fn row ->
        Enum.map_join(columns, ",", &csv_cell(Map.get(row, &1)))
      end)

    header <> "\n" <> body <> "\n"
  end

  defp csv_cell(value) when is_binary(value) do
    "\"" <> String.replace(value, "\"", "\"\"") <> "\""
  end

  defp csv_cell(value), do: to_string(value)

  defp normalize_filters(filters) when is_map(filters) do
    normalized =
      filters
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.into(%{})

    row_limit =
      normalized
      |> Map.get("row_limit", Application.get_env(:report_forge, :default_row_limit, 25))
      |> parse_integer(Application.get_env(:report_forge, :default_row_limit, 25))

    Map.put(normalized, "row_limit", row_limit)
  end

  defp normalize_filters(_filters), do: %{}

  defp validation_details(template_name, format, requested_by, raw_filters, filters) do
    max_row_limit = Application.get_env(:report_forge, :max_row_limit, 500)

    []
    |> maybe_add_error(
      template_name not in Map.keys(@templates),
      "template_name",
      "must be one of #{Enum.join(Map.keys(@templates), ", ")}"
    )
    |> maybe_add_error(
      format not in @formats,
      "format",
      "must be one of #{Enum.join(@formats, ", ")}"
    )
    |> maybe_add_error(
      is_nil(requested_by) or byte_size(requested_by) < 3,
      "requested_by",
      "must contain at least 3 characters"
    )
    |> maybe_add_error(not is_map(raw_filters), "filters", "must be an object")
    |> maybe_add_error(
      Map.get(filters, "row_limit", 0) < 1 or Map.get(filters, "row_limit", 0) > max_row_limit,
      "filters.row_limit",
      "must be between 1 and #{max_row_limit}"
    )
  end

  defp read_string(attrs, key) do
    case read_value(attrs, key) do
      value when is_binary(value) ->
        value
        |> String.trim()
        |> case do
          "" -> nil
          trimmed -> trimmed
        end

      _other ->
        nil
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _other -> default
    end
  end

  defp parse_integer(_value, default), do: default

  defp read_filters(attrs) do
    read_value(attrs, "filters") || %{}
  end

  defp read_value(attrs, "template_name"),
    do: Map.get(attrs, "template_name") || Map.get(attrs, :template_name)

  defp read_value(attrs, "format"), do: Map.get(attrs, "format") || Map.get(attrs, :format)

  defp read_value(attrs, "requested_by"),
    do: Map.get(attrs, "requested_by") || Map.get(attrs, :requested_by)

  defp read_value(attrs, "idempotency_key"),
    do: Map.get(attrs, "idempotency_key") || Map.get(attrs, :idempotency_key)

  defp read_value(attrs, "correlation_id"),
    do: Map.get(attrs, "correlation_id") || Map.get(attrs, :correlation_id)

  defp read_value(attrs, "filters"), do: Map.get(attrs, "filters") || Map.get(attrs, :filters)
  defp read_value(_attrs, _key), do: nil

  defp maybe_add_error(details, false, _field, _issue), do: details

  defp maybe_add_error(details, true, field, issue),
    do: details ++ [%{field: field, issue: issue}]
end
