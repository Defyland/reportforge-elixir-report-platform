defmodule ReportForge.ArtifactStorageS3Test do
  use ReportForge.Case, async: false

  alias ReportForge.ArtifactStorage
  alias ReportForge.ArtifactStorage.S3
  alias ReportForge.Repo
  alias ReportForge.Reports.Artifact

  defmodule FakeS3Client do
    @behaviour ReportForge.ArtifactStorage.S3HTTPClient

    def child_spec(responses) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [responses]}
      }
    end

    def start_link(responses) do
      Agent.start_link(fn -> %{requests: [], responses: responses} end, name: __MODULE__)
    end

    @impl ReportForge.ArtifactStorage.S3HTTPClient
    def request(method, url, headers, body) do
      Agent.get_and_update(__MODULE__, fn state ->
        response = List.first(state.responses) || %{status: 200, body: ""}
        responses = Enum.drop(state.responses, 1)
        request = %{method: method, url: url, headers: headers, body: body}

        outcome =
          case response do
            {:error, reason} -> {:error, reason}
            response -> {:ok, response}
          end

        {outcome, %{state | requests: state.requests ++ [request], responses: responses}}
      end)
    end

    def requests do
      Agent.get(__MODULE__, & &1.requests)
    end
  end

  setup do
    original_adapter = Application.get_env(:report_forge, :artifact_storage_adapter)
    original_s3 = Application.get_env(:report_forge, :artifact_storage_s3)

    on_exit(fn ->
      Application.put_env(:report_forge, :artifact_storage_adapter, original_adapter)
      Application.put_env(:report_forge, :artifact_storage_s3, original_s3)
    end)

    :ok
  end

  test "uploads artifacts to S3-compatible storage and resolves a presigned redirect" do
    configure_s3!(responses: [%{status: 200, body: ""}])

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization)
    expires_at = DateTime.add(ReportForge.utc_now(), 60, :second)
    artifact_id = ReportForge.generate_id("art")

    assert {:ok, artifact} =
             ArtifactStorage.put_artifact(%{
               id: artifact_id,
               organization_id: organization.id,
               report_id: report.id,
               token: "s3-storage-token",
               body: "csv-body",
               filename: "report.csv",
               content_type: "text/csv",
               expires_at: expires_at
             })

    assert artifact.body == nil
    assert artifact.storage_key == "#{report.id}/#{artifact_id}-report.csv"
    assert artifact.byte_size == byte_size("csv-body")
    assert artifact.checksum == ReportForge.sha256("csv-body")

    assert [put_request] = FakeS3Client.requests()
    assert put_request.method == :put
    assert put_request.url =~ "http://minio.test:9000/reportforge-test/#{artifact.storage_key}"
    assert put_request.body == "csv-body"
    assert header(put_request, "x-amz-meta-checksum") == ReportForge.sha256("csv-body")
    assert header(put_request, "x-amz-content-sha256") == ReportForge.sha256("csv-body")
    assert header(put_request, "authorization") =~ "AWS4-HMAC-SHA256 Credential=minio/"

    assert {:ok, {:redirect, redirect_url}} = ArtifactStorage.open_artifact(artifact)
    redirect = URI.parse(redirect_url)
    query = URI.decode_query(redirect.query)

    assert redirect.scheme == "http"
    assert redirect.host == "minio.test"
    assert redirect.path == "/reportforge-test/#{artifact.storage_key}"
    assert query["X-Amz-Algorithm"] == "AWS4-HMAC-SHA256"
    assert query["X-Amz-Expires"] == "120"
    assert query["X-Amz-SignedHeaders"] == "host"
    assert query["X-Amz-Signature"]
  end

  test "classifies S3 upload failures as transient storage errors without inserting metadata" do
    configure_s3!(responses: [%{status: 503, body: "service unavailable"}])

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization)

    assert {:error, {"storage_unavailable", message}} =
             ArtifactStorage.put_artifact(%{
               id: ReportForge.generate_id("art"),
               organization_id: organization.id,
               report_id: report.id,
               token: "s3-failed-token",
               body: "csv-body",
               filename: "report.csv",
               content_type: "text/csv",
               expires_at: DateTime.add(ReportForge.utc_now(), 60, :second)
             })

    assert message =~ "S3 responded with status 503"
    refute Repo.get_by(Artifact, token: "s3-failed-token")
  end

  test "deletes uploaded S3 objects when database metadata insertion fails" do
    configure_s3!(
      responses: [
        %{status: 200, body: ""},
        %{status: 200, body: ""},
        %{status: 204, body: ""}
      ]
    )

    %{organization: organization} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization)
    expires_at = DateTime.add(ReportForge.utc_now(), 60, :second)

    assert {:ok, _artifact} =
             ArtifactStorage.put_artifact(%{
               id: ReportForge.generate_id("art"),
               organization_id: organization.id,
               report_id: report.id,
               token: "s3-first-token",
               body: "csv-body",
               filename: "report.csv",
               content_type: "text/csv",
               expires_at: expires_at
             })

    duplicate_artifact_id = ReportForge.generate_id("art")

    assert {:error, %Ecto.Changeset{}} =
             ArtifactStorage.put_artifact(%{
               id: duplicate_artifact_id,
               organization_id: organization.id,
               report_id: report.id,
               token: "s3-second-token",
               body: "csv-body",
               filename: "report.csv",
               content_type: "text/csv",
               expires_at: expires_at
             })

    assert Enum.map(FakeS3Client.requests(), & &1.method) == [:put, :put, :delete]
    assert List.last(FakeS3Client.requests()).url =~ duplicate_artifact_id
    refute Repo.get_by(Artifact, token: "s3-second-token")
  end

  test "download endpoint redirects S3-backed artifacts to a presigned object URL" do
    configure_s3!(responses: [%{status: 200, body: ""}])

    %{organization: organization, bootstrap_api_key: token} = Fixtures.organization_fixture()
    report = Fixtures.report_fixture(organization, %{"format" => "csv"})

    assert %{success: 1} = drain_report_jobs()

    download_conn =
      json_request(:get, "/api/v1/reports/#{report.id}/download", nil, [{"x-api-key", token}])

    assert download_conn.status == 200

    download_path =
      json_response(download_conn) |> get_in(["data", "url"]) |> URI.parse() |> Map.fetch!(:path)

    artifact_conn = json_request(:get, download_path)

    assert artifact_conn.status == 302
    assert [location] = get_resp_header(artifact_conn, "location")
    assert location =~ "http://minio.test:9000/reportforge-test/"
    assert URI.decode_query(URI.parse(location).query)["X-Amz-Signature"]
  end

  defp configure_s3!(opts) do
    start_supervised!({FakeS3Client, Keyword.fetch!(opts, :responses)})

    Application.put_env(:report_forge, :artifact_storage_adapter, S3)

    Application.put_env(:report_forge, :artifact_storage_s3,
      access_key_id: "minio",
      bucket: "reportforge-test",
      endpoint: "http://minio.test:9000",
      force_path_style: true,
      http_client: FakeS3Client,
      presign_ttl_seconds: 120,
      region: "us-east-1",
      secret_access_key: "minio-secret"
    )
  end

  defp header(request, name) do
    Enum.find_value(request.headers, fn {header_name, value} ->
      if header_name == name, do: value
    end)
  end
end
