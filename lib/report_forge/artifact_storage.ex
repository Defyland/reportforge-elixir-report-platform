defmodule ReportForge.ArtifactStorage do
  @moduledoc false

  alias ReportForge.Reports.Artifact

  @type artifact_source :: {:file, Path.t()} | {:binary, binary()} | {:redirect, String.t()}

  @callback put_artifact(map()) ::
              {:ok, Artifact.t()} | {:error, Ecto.Changeset.t() | {String.t(), String.t()}}
  @callback fetch_artifact(String.t() | nil) ::
              {:ok, Artifact.t()} | {:error, :conflict | :not_found | :gone}
  @callback open_artifact(Artifact.t()) ::
              {:ok, artifact_source()} | {:error, :not_found | {String.t(), String.t()}}
  @callback delete_for_report(String.t()) :: non_neg_integer()
  @callback expired_report_ids(DateTime.t()) :: [String.t()]
  @callback delete_expired(DateTime.t()) :: non_neg_integer()

  def put_artifact(attrs), do: adapter().put_artifact(attrs)
  def fetch_artifact(token), do: adapter().fetch_artifact(token)
  def open_artifact(%Artifact{} = artifact), do: adapter().open_artifact(artifact)
  def delete_for_report(report_id), do: adapter().delete_for_report(report_id)
  def expired_report_ids(now), do: adapter().expired_report_ids(now)
  def delete_expired(now), do: adapter().delete_expired(now)

  defp adapter do
    Application.get_env(
      :report_forge,
      :artifact_storage_adapter,
      ReportForge.ArtifactStorage.Local
    )
  end
end
