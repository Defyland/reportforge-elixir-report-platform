defmodule ReportForge.OtlpExportTest do
  use ReportForge.Case, async: false

  alias ReportForge.Reports

  defmodule CollectorStub do
    import Plug.Conn

    def init(test_pid), do: test_pid

    def call(conn, test_pid) do
      {:ok, body, conn} = read_full_body(conn)

      send(test_pid, {:otlp_export, conn.request_path, conn.req_headers, body})

      response_body =
        :opentelemetry_exporter_trace_service_pb.encode_msg(
          %{},
          :export_trace_service_response
        )

      conn
      |> put_resp_header("content-type", "application/x-protobuf")
      |> send_resp(200, response_body)
    end

    defp read_full_body(conn, body \\ "") do
      case read_body(conn) do
        {:ok, chunk, conn} ->
          {:ok, body <> chunk, conn}

        {:more, chunk, conn} ->
          read_full_body(conn, body <> chunk)
      end
    end
  end

  test "exports OTLP trace payloads for HTTP requests and async workers" do
    {:ok, collector} =
      Bandit.start_link(
        plug: {CollectorStub, self()},
        port: 4318,
        ip: {127, 0, 0, 1}
      )

    enable_otlp_export!("http://127.0.0.1:4318")

    on_exit(fn ->
      Process.exit(collector, :normal)
      disable_otlp_export!()
    end)

    %{organization: organization, bootstrap_api_key: api_key} = Fixtures.organization_fixture()

    conn =
      json_request(
        :post,
        "/api/v1/reports",
        %{
          "report" => %{
            "template_name" => "cash_position",
            "format" => "csv",
            "requested_by" => "observability@example.com",
            "idempotency_key" => "idemp-otlp-export",
            "filters" => %{"row_limit" => 3}
          }
        },
        [{"x-api-key", api_key}]
      )

    assert conn.status == 202
    report_id = json_response(conn)["data"]["id"]
    assert %{success: 1} = drain_report_jobs()
    assert {:ok, _report} = Reports.get_report(organization, report_id)

    assert :ok = :otel_tracer_provider.force_flush()

    exported_requests =
      wait_for_exports([], fn exports ->
        span_names =
          exports
          |> Enum.flat_map(&decode_span_names/1)
          |> MapSet.new()

        MapSet.member?(span_names, "POST /api/v1/reports") and
          MapSet.member?(span_names, "reports.worker.run")
      end)

    span_names =
      exported_requests
      |> Enum.flat_map(&decode_span_names/1)
      |> MapSet.new()

    assert MapSet.member?(span_names, "POST /api/v1/reports")
    assert MapSet.member?(span_names, "reports.worker.run")
    assert Enum.all?(exported_requests, &(&1.path == "/v1/traces"))
    assert Enum.all?(exported_requests, &protobuf_content_type?(&1.headers))
  end

  defp wait_for_exports(exports, predicate, attempts \\ 80)

  defp wait_for_exports(exports, _predicate, 0), do: exports

  defp wait_for_exports(exports, predicate, attempts) do
    if predicate.(exports) do
      exports
    else
      receive do
        {:otlp_export, path, headers, body} ->
          wait_for_exports(
            [%{path: path, headers: headers, body: body} | exports],
            predicate,
            attempts - 1
          )
      after
        25 ->
          wait_for_exports(exports, predicate, attempts - 1)
      end
    end
  end

  defp decode_span_names(export_request) do
    export_request.body
    |> :opentelemetry_exporter_trace_service_pb.decode_msg(:export_trace_service_request)
    |> Map.get(:resource_spans, [])
    |> Enum.flat_map(fn resource_span ->
      resource_span
      |> Map.get(:scope_spans, [])
      |> Enum.flat_map(fn scope_span ->
        scope_span
        |> Map.get(:spans, [])
        |> Enum.map(&to_string(Map.get(&1, :name)))
      end)
    end)
  end

  defp protobuf_content_type?(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == "content-type", do: String.downcase(value), else: nil
    end)
    |> case do
      nil -> false
      value -> String.contains?(value, "application/x-protobuf")
    end
  end

  defp enable_otlp_export!(endpoint) do
    Application.put_env(:opentelemetry, :traces_exporter, :otlp)
    Application.put_env(:opentelemetry_exporter, :otlp_protocol, :http_protobuf)
    Application.put_env(:opentelemetry_exporter, :otlp_endpoint, endpoint)

    :ok = Application.stop(:opentelemetry)
    {:ok, _apps} = Application.ensure_all_started(:opentelemetry)
  end

  defp disable_otlp_export! do
    Application.put_env(:opentelemetry, :traces_exporter, :none)
    Application.delete_env(:opentelemetry_exporter, :otlp_endpoint)

    :ok = Application.stop(:opentelemetry)
    {:ok, _apps} = Application.ensure_all_started(:opentelemetry)
  end
end
