defmodule ReportForge.Audit do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Changeset
  alias ReportForge
  alias ReportForge.Audit.Log
  alias ReportForge.Observability
  alias ReportForge.Repo
  alias ReportForge.Tracing

  def list_logs(organization_id \\ nil) do
    Log
    |> maybe_scope_to_organization(organization_id)
    |> order_by([log], asc: log.inserted_at, asc: log.id)
    |> Repo.all()
  end

  def record(attrs) when is_map(attrs) do
    attrs
    |> enrich_attrs()
    |> then(&Log.changeset(%Log{}, &1))
    |> Repo.insert()
  end

  def record_best_effort(attrs) when is_map(attrs) do
    case record(attrs) do
      {:ok, log} ->
        {:ok, log}

      {:error, %Changeset{} = changeset} ->
        Observability.log(:error, "audit_record_failed", %{
          action: Map.get(attrs, :action) || Map.get(attrs, "action"),
          errors: translate_changeset_errors(changeset)
        })

        {:error, changeset}
    end
  end

  defp enrich_attrs(attrs) do
    logger_metadata = Logger.metadata()
    normalized = symbolize_known_keys(attrs)
    trace_metadata = Tracing.trace_metadata()
    {actor_type, actor_id} = infer_actor(normalized, logger_metadata)

    normalized
    |> Map.put_new(:id, ReportForge.generate_id("aud"))
    |> Map.put_new(:actor_type, actor_type)
    |> Map.put_new(:actor_id, actor_id)
    |> Map.put_new(:organization_id, logger_metadata[:organization_id])
    |> Map.put_new(:outcome, "success")
    |> Map.put_new(:request_id, logger_metadata[:request_id])
    |> Map.put_new(:correlation_id, logger_metadata[:correlation_id])
    |> Map.put_new(:trace_id, trace_metadata[:trace_id])
    |> Map.put_new(:span_id, trace_metadata[:span_id])
    |> Map.update(:metadata, %{}, &normalize_metadata/1)
  end

  defp infer_actor(attrs, logger_metadata) do
    cond do
      is_binary(attrs[:actor_type]) ->
        {attrs[:actor_type], attrs[:actor_id]}

      is_binary(logger_metadata[:api_key_id]) ->
        {"api_key", logger_metadata[:api_key_id]}

      is_binary(logger_metadata[:organization_id]) ->
        {"organization", logger_metadata[:organization_id]}

      true ->
        {"system", attrs[:actor_id]}
    end
  end

  defp maybe_scope_to_organization(query, nil), do: query

  defp maybe_scope_to_organization(query, organization_id) do
    where(query, [log], log.organization_id == ^organization_id)
  end

  defp symbolize_known_keys(attrs) do
    known_keys = %{
      "id" => :id,
      "organization_id" => :organization_id,
      "actor_type" => :actor_type,
      "actor_id" => :actor_id,
      "action" => :action,
      "resource_type" => :resource_type,
      "resource_id" => :resource_id,
      "outcome" => :outcome,
      "request_id" => :request_id,
      "correlation_id" => :correlation_id,
      "trace_id" => :trace_id,
      "span_id" => :span_id,
      "metadata" => :metadata
    }

    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {Map.get(known_keys, key, key), value}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(metadata) when is_list(metadata), do: Map.new(metadata)
  defp normalize_metadata(_metadata), do: %{}

  defp translate_changeset_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
