defmodule ReportForge.ArtifactStorage.Database do
  @moduledoc false

  @behaviour ReportForge.ArtifactStorage

  import Ecto.Query

  alias ReportForge.Repo
  alias ReportForge.Reports.Artifact
  alias ReportForge.Signing

  @impl ReportForge.ArtifactStorage
  def put_artifact(attrs) do
    %Artifact{} |> Artifact.changeset(attrs) |> Repo.insert()
  end

  @impl ReportForge.ArtifactStorage
  def fetch_artifact(nil), do: {:error, :conflict}

  def fetch_artifact(token) do
    case Repo.get_by(Artifact, token: token) do
      nil ->
        {:error, :not_found}

      artifact ->
        if Signing.expired?(artifact.expires_at) do
          {:error, :gone}
        else
          {:ok, artifact}
        end
    end
  end

  @impl ReportForge.ArtifactStorage
  def delete_for_report(report_id) do
    {count, _rows} =
      Repo.delete_all(from(artifact in Artifact, where: artifact.report_id == ^report_id))

    count
  end

  @impl ReportForge.ArtifactStorage
  def expired_report_ids(now) do
    now
    |> expired_query()
    |> select([artifact], artifact.report_id)
    |> Repo.all()
  end

  @impl ReportForge.ArtifactStorage
  def delete_expired(now) do
    {count, _rows} = Repo.delete_all(expired_query(now))
    count
  end

  defp expired_query(now), do: from(artifact in Artifact, where: artifact.expires_at <= ^now)
end
