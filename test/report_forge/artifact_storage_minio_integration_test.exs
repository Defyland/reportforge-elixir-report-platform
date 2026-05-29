defmodule ReportForge.ArtifactStorageMinioIntegrationTest do
  use ReportForge.Case, async: false

  alias ReportForge.ArtifactStorage
  alias ReportForge.ArtifactStorage.S3

  @moduletag :minio

  if System.get_env("REPORT_FORGE_MINIO_INTEGRATION") != "1" do
    @moduletag skip: "set REPORT_FORGE_MINIO_INTEGRATION=1 to run against a real MinIO service"
  end

  setup do
    original_adapter = Application.get_env(:report_forge, :artifact_storage_adapter)
    original_s3 = Application.get_env(:report_forge, :artifact_storage_s3)

    Application.put_env(:report_forge, :artifact_storage_adapter, S3)

    Application.put_env(:report_forge, :artifact_storage_s3,
      access_key_id: System.get_env("REPORT_FORGE_S3_ACCESS_KEY_ID", "minioadmin"),
      bucket: System.get_env("REPORT_FORGE_S3_BUCKET", "reportforge-artifacts"),
      endpoint: System.get_env("REPORT_FORGE_S3_ENDPOINT", "http://127.0.0.1:9000"),
      force_path_style: true,
      presign_ttl_seconds: 120,
      public_endpoint: System.get_env("REPORT_FORGE_S3_PUBLIC_ENDPOINT", "http://127.0.0.1:9000"),
      region: System.get_env("REPORT_FORGE_S3_REGION", "us-east-1"),
      secret_access_key: System.get_env("REPORT_FORGE_S3_SECRET_ACCESS_KEY", "minioadmin")
    )

    on_exit(fn ->
      Application.put_env(:report_forge, :artifact_storage_adapter, original_adapter)
      Application.put_env(:report_forge, :artifact_storage_s3, original_s3)
    end)

    :ok
  end

  test "stores, presigns, downloads, and deletes an artifact through real MinIO" do
    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization)
    body = "as_of_date,account_id\n2026-05-29,acct_001\n"

    assert {:ok, artifact} =
             ArtifactStorage.put_artifact(%{
               id: ReportForge.generate_id("art"),
               organization_id: organization.id,
               report_id: report.id,
               token: "minio-#{System.unique_integer([:positive])}",
               body: body,
               filename: "minio-report.csv",
               content_type: "text/csv",
               expires_at: DateTime.add(ReportForge.utc_now(), 300, :second)
             })

    assert artifact.body == nil
    assert artifact.storage_key =~ report.id

    assert {:ok, {:redirect, presigned_url}} = ArtifactStorage.open_artifact(artifact)
    assert {:ok, %{status: 200, body: ^body}} = http_get(presigned_url)

    assert ArtifactStorage.delete_for_report(report.id) == 1
    assert {:ok, %{status: 404}} = http_get(presigned_url)
  end

  defp http_get(url) do
    {:ok, _started} = Application.ensure_all_started(:inets)

    case :httpc.request(:get, {to_charlist(url), []}, [], body_format: :binary) do
      {:ok, {{_version, status, _reason}, _headers, body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
