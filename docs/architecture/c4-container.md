# C4 Container

## Containers

| Container | Responsibility | Technology |
| --- | --- | --- |
| API service | HTTP edge, auth, report commands, signed download routing, metrics | Elixir, Plug, Bandit |
| Worker runtime | Durable report execution, retry, cleanup, retention | Oban inside the Elixir application |
| Database | Tenant state, report metadata, events, audit logs, Oban jobs | PostgreSQL |
| Artifact storage | Generated artifact bytes | Local filesystem, MinIO, or S3-compatible storage |
| Observability stack | Metrics, traces, dashboard evidence | OpenTelemetry Collector, Prometheus, Grafana |

## Container Relationships

- API service writes command state and reads projections from PostgreSQL.
- Worker runtime consumes Oban jobs from PostgreSQL and writes lifecycle events.
- API service and worker runtime share `ReportForge.ArtifactStorage`.
- Signed URLs resolve through API metadata before bytes are streamed or
  redirected.
- Telemetry and tracing are emitted from both HTTP and worker paths.

## Scaling Shape

The API service can scale horizontally when PostgreSQL, Oban queue settings, and
artifact storage are configured for the target environment. Worker concurrency
should scale separately from HTTP concurrency so large exports do not starve
request handling.
