defmodule ReportForge.ArtifactStorageTest do
  use ReportForge.Case, async: false

  alias ReportForge.ArtifactStorage
  alias ReportForge.Repo
  alias ReportForge.Reports.Artifact

  test "stores metadata, fetches, opens, expires, and deletes object artifacts" do
    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization)
    expires_at = DateTime.add(ReportForge.utc_now(), 60, :second)

    assert {:ok, artifact} =
             ArtifactStorage.put_artifact(%{
               id: ReportForge.generate_id("art"),
               organization_id: organization.id,
               report_id: report.id,
               token: "storage-token",
               body: "csv-body",
               filename: "report.csv",
               content_type: "text/csv",
               expires_at: expires_at
             })

    assert {:ok, fetched_artifact} = ArtifactStorage.fetch_artifact("storage-token")
    assert fetched_artifact.id == artifact.id
    assert fetched_artifact.body == nil
    assert fetched_artifact.storage_key =~ report.id
    assert fetched_artifact.byte_size == byte_size("csv-body")
    assert fetched_artifact.checksum == ReportForge.sha256("csv-body")

    assert {:ok, {:file, path}} = ArtifactStorage.open_artifact(fetched_artifact)
    assert File.read!(path) == "csv-body"

    assert ArtifactStorage.expired_report_ids(DateTime.add(expires_at, 1, :second)) == [
             report.id
           ]

    assert ArtifactStorage.delete_for_report(report.id) == 1
    refute Repo.get(Artifact, artifact.id)
    refute File.exists?(path)
  end

  test "returns gone for expired artifacts without deleting them" do
    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization)
    expires_at = DateTime.add(ReportForge.utc_now(), -1, :second)

    assert {:ok, _artifact} =
             ArtifactStorage.put_artifact(%{
               id: ReportForge.generate_id("art"),
               organization_id: organization.id,
               report_id: report.id,
               token: "expired-storage-token",
               body: "csv-body",
               filename: "report.csv",
               content_type: "text/csv",
               expires_at: expires_at
             })

    {:ok, expired_artifact} =
      Repo.get_by(Artifact, token: "expired-storage-token") |> ArtifactStorage.open_artifact()

    assert {:file, path} = expired_artifact

    assert ArtifactStorage.fetch_artifact("expired-storage-token") == {:error, :gone}
    assert ArtifactStorage.delete_expired(ReportForge.utc_now()) == 1
    refute File.exists?(path)
  end
end
