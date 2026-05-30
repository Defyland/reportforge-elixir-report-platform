# Deployment View

## Current Local Production-Like Topology

The repository ships a Docker Compose topology that is useful for portfolio and
engineering validation:

- ReportForge API and worker runtime
- PostgreSQL
- MinIO for S3-compatible object storage
- OpenTelemetry Collector
- Prometheus
- Grafana

This topology validates the shape of the service without claiming that the
repository already provisions production infrastructure.

## Runtime Configuration

Important environment variables include:

- `DATABASE_URL`
- `SIGNING_SECRET` or `SIGNING_SECRET_FILE`
- `REPORT_FORGE_ARTIFACT_STORAGE_ADAPTER`
- `REPORT_FORGE_S3_BUCKET`
- `REPORT_FORGE_S3_ENDPOINT`
- `REPORT_FORGE_S3_ACCESS_KEY_ID`
- `REPORT_FORGE_S3_SECRET_ACCESS_KEY` or
  `REPORT_FORGE_S3_SECRET_ACCESS_KEY_FILE`
- `OTEL_EXPORTER_OTLP_ENDPOINT`

## Production Deployment Expectations

A real deployment should add TLS, managed PostgreSQL, managed object storage,
secret manager integration, resource limits, worker concurrency sizing, backup
and restore drills, alert routing, and migration rollback procedures.

## Deferred Platform Choices

Kubernetes, Helm, Terraform, data lake, and CDC pipelines are intentionally
deferred. They should be introduced after a target runtime, throughput profile,
retention policy, and operational ownership model are known.
