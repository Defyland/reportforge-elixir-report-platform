# Operational Cost

## Infrastructure Components

ReportForge needs an API and worker runtime, PostgreSQL, artifact storage, and
an observability stack. The local production-like topology uses Docker Compose
with PostgreSQL, MinIO, OpenTelemetry Collector, Prometheus, and Grafana.

## Cost Drivers

- PostgreSQL storage and IOPS for reports, events, audit logs, and Oban jobs.
- Object storage bytes, requests, retention, lifecycle, and egress for
  generated artifacts.
- Worker CPU and memory for export generation and serialization.
- Observability retention for logs, metrics, traces, and dashboards.
- Engineering time for migrations, incidents, replay, cleanup, and compliance
  reviews.

## Debugging Cost

Async report generation is harder to debug than inline exports. The repository
reduces that cost with report events, audit logs, request IDs, correlation IDs,
trace IDs, structured logs, and runbooks.

## Deployment Cost

The current repo does not include Terraform, Kubernetes, Helm, or managed cloud
configuration. That is intentional: those choices should follow the target
runtime. A real production deployment must budget for TLS, secrets, database
backups, worker autoscaling, resource limits, and release rollback.

## Backup And Retention Cost

Financial artifacts and report metadata have different backup needs. PostgreSQL
must preserve authorization, metadata, audit, and event history. Object storage
must preserve artifact bytes only as long as retention requires. Legal hold and
restore drills are future production concerns.

## Monitoring Cost

Prometheus and Grafana evidence exists locally, but production requires alert
routing, SLO definitions, dashboard ownership, and retention decisions. Without
ownership, observability becomes data exhaust instead of operational leverage.

## Vendor Lock-In

S3-compatible storage keeps the object-storage boundary portable. PostgreSQL
and Oban create deliberate coupling because they provide durable consistency and
queue semantics with a small operational footprint.

## Simpler Alternatives Rejected

- Inline report generation was rejected because it couples user latency to slow
  queries and file IO.
- Storing artifact bytes in PostgreSQL was rejected for production shape because
  it increases database backup, restore, and storage pressure.
- Kubernetes was deferred because orchestration choice is less important than
  lifecycle correctness, storage boundaries, and observability at this stage.
