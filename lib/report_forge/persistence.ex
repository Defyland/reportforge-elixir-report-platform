defmodule ReportForge.Persistence do
  @moduledoc false

  alias ReportForge.Identity.{ApiKey, Organization}
  alias ReportForge.Repo
  alias ReportForge.Reports.{Artifact, Report, ReportEvent}

  def register_organization_with_bootstrap_key(attrs, api_key_name \\ "bootstrap") do
    api_key_attrs =
      Map.get(attrs, :api_key) || Map.get(attrs, "api_key") ||
        generated_api_key_attrs(api_key_name)

    Repo.transaction(fn ->
      with {:ok, organization} <-
             %Organization{} |> Organization.changeset(attrs) |> Repo.insert(),
           {:ok, api_key} <-
             %ApiKey{}
             |> ApiKey.changeset(Map.put(api_key_attrs, :organization_id, organization.id))
             |> Repo.insert() do
        %{organization: organization, api_key: api_key}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def insert_report(attrs) do
    %Report{} |> Report.changeset(attrs) |> Repo.insert()
  end

  def insert_report_event(attrs) do
    %ReportEvent{} |> ReportEvent.changeset(attrs) |> Repo.insert()
  end

  def insert_report_artifact(attrs) do
    %Artifact{} |> Artifact.changeset(attrs) |> Repo.insert()
  end

  def list_report_events(report_id) do
    import Ecto.Query, only: [from: 2]

    Repo.all(
      from(event in ReportEvent,
        where: event.report_id == ^report_id,
        order_by: [asc: event.inserted_at]
      )
    )
  end

  defp generated_api_key_attrs(name) do
    {api_key, _token} = ApiKey.issue("pending", name)

    %{
      id: api_key.id,
      name: api_key.name,
      key_prefix: api_key.key_prefix,
      hashed_secret: api_key.hashed_secret,
      token_hint: api_key.token_hint,
      last_used_at: api_key.last_used_at,
      revoked_at: api_key.revoked_at
    }
  end
end
