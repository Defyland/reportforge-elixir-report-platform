# Observability

## Current implementation

- request ID and correlation ID are attached by [lib/report_forge_web/request_context.ex](../../lib/report_forge_web/request_context.ex)
- each HTTP request starts a server span and returns a `traceparent` header plus `meta.trace_id`
- report creation spans propagate trace context into async workers through [lib/report_forge/tracing.ex](../../lib/report_forge/tracing.ex) and [lib/report_forge/reports/worker.ex](../../lib/report_forge/reports/worker.ex)
- report lifecycle events persist `trace_id` and `span_id` for cross-request and async correlation
- structured JSON log payloads are emitted through [lib/report_forge/observability.ex](../../lib/report_forge/observability.ex)
- OTLP exporter wiring is configured through `:opentelemetry` and `:opentelemetry_exporter`
- Prometheus-style metrics are exposed by [lib/report_forge/metrics.ex](../../lib/report_forge/metrics.ex)
- explicit health check and readiness check endpoints exist in [lib/report_forge_web/router.ex](../../lib/report_forge_web/router.ex), and readiness now validates PostgreSQL reachability, Oban availability, and signing-secret presence

## Current metric families

- `reportforge_http_requests_total`
- `reportforge_http_request_duration_ms_sum`
- `reportforge_http_request_duration_ms_count`
- `reportforge_reports_created_total`
- `reportforge_reports_completed_total`
- `reportforge_report_duration_ms_sum`
- `reportforge_report_duration_ms_count`
- `reportforge_inflight_reports`

## Dashboard definition

The initial Grafana dashboard definition lives in [grafana-dashboard.json](./grafana-dashboard.json).

## Trace proof in the current slice

- HTTP responses expose `traceparent` and `meta.trace_id`
- the report events API exposes the same `trace_id` across `report.requested`, `report.started`, progress, and `report.completed`
- worker spans use a different `span_id` from the request span while staying inside the same trace
- this behavior is covered by [test/report_forge_web/router_test.exs](../../test/report_forge_web/router_test.exs) and [test/report_forge/reports/worker_test.exs](../../test/report_forge/reports/worker_test.exs)
- exported OTLP traces are validated end-to-end by [test/report_forge/otlp_export_test.exs](../../test/report_forge/otlp_export_test.exs), which boots a local collector stub, forces OTLP export, and decodes the emitted protobuf payload

## Remaining gaps

- metrics are custom text exposition, not yet emitted through an OpenTelemetry metric pipeline
- collector deployment, retention, and dashboarding are still environment-specific concerns outside the repository slice
