defmodule ReportForge.ArtifactStorage.Local do
  @moduledoc false

  @behaviour ReportForge.ArtifactStorage

  import Ecto.Query

  alias ReportForge
  alias ReportForge.Repo
  alias ReportForge.Reports.Artifact
  alias ReportForge.Signing

  @impl ReportForge.ArtifactStorage
  # sobelow_skip ["Traversal.FileModule"]
  def put_artifact(%{body: body} = attrs) when is_binary(body) do
    storage_key = storage_key(attrs)
    path = local_path(storage_key)

    with :ok <- ensure_storage_dir(path),
         :ok <- File.write(path, body),
         {:ok, artifact} <- insert_metadata(attrs, storage_key, body) do
      {:ok, artifact}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        File.rm(path)
        {:error, changeset}

      {:error, reason} ->
        {:error, {"storage_unavailable", storage_error(reason)}}
    end
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
  def open_artifact(%Artifact{storage_key: storage_key}) when is_binary(storage_key) do
    path = local_path(storage_key)

    if File.regular?(path) do
      {:ok, {:file, path}}
    else
      {:error, :not_found}
    end
  end

  def open_artifact(%Artifact{body: body}) when is_binary(body), do: {:ok, {:binary, body}}
  def open_artifact(%Artifact{}), do: {:error, :not_found}

  @impl ReportForge.ArtifactStorage
  def delete_for_report(report_id) do
    artifacts = Repo.all(from(artifact in Artifact, where: artifact.report_id == ^report_id))

    {count, _rows} =
      Repo.delete_all(from(artifact in Artifact, where: artifact.report_id == ^report_id))

    Enum.each(artifacts, &delete_file/1)
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
    artifacts = Repo.all(expired_query(now))
    {count, _rows} = Repo.delete_all(expired_query(now))
    Enum.each(artifacts, &delete_file/1)
    count
  end

  def reset! do
    root = storage_root()

    if String.contains?(root, "report_forge") do
      File.rm_rf!(root)
    end
  end

  def storage_root do
    Application.get_env(
      :report_forge,
      :artifact_storage_path,
      Path.join(System.tmp_dir!(), "report_forge_artifacts")
    )
  end

  defp insert_metadata(attrs, storage_key, body) do
    attrs =
      attrs
      |> Map.delete(:body)
      |> Map.merge(%{
        storage_key: storage_key,
        byte_size: byte_size(body),
        checksum: ReportForge.sha256(body)
      })

    %Artifact{} |> Artifact.changeset(attrs) |> Repo.insert()
  end

  defp storage_key(attrs) do
    report_id = Map.fetch!(attrs, :report_id)
    id = Map.fetch!(attrs, :id)
    filename = attrs |> Map.fetch!(:filename) |> Path.basename()

    Path.join([report_id, "#{id}-#{filename}"])
  end

  defp local_path(storage_key) do
    root = Path.expand(storage_root())
    path = Path.expand(Path.join(root, storage_key))

    if String.starts_with?(path, root <> "/") do
      path
    else
      raise ArgumentError, "artifact storage key escapes storage root"
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp ensure_storage_dir(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp delete_file(%Artifact{storage_key: storage_key}) when is_binary(storage_key) do
    storage_key
    |> local_path()
    |> File.rm()

    :ok
  end

  defp delete_file(%Artifact{}), do: :ok

  defp expired_query(now), do: from(artifact in Artifact, where: artifact.expires_at <= ^now)

  defp storage_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp storage_error(%File.Error{} = error), do: Exception.message(error)
  defp storage_error(reason), do: inspect(reason)
end
