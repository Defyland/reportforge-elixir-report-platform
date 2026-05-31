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

The application container is a release-based non-root container built from
digest-pinned base images. Runtime database settings are read in
`config/runtime.exs`, so release containers honor `DATABASE_URL` or
`REPORT_FORGE_DB_*` environment variables instead of baking build-time database
defaults into the image.

The Compose stack runs release migrations through a one-shot
`reportforge-migrate` service that executes `ReportForge.Release.migrate/0`.
The API container starts only after that service completes successfully. This is
closer to a production deployment shape than running migrations inline in the
long-lived API process, while still avoiding external managed services. The
image declares a container healthcheck against `/readyz` so orchestrators and
Compose gate dependents on database, Oban, and signer readiness rather than
only process liveness.

The local Compose service also enables runtime hardening controls that are
available without a cluster: `read_only: true`, `/tmp` as `tmpfs`,
`no-new-privileges`, dropped Linux capabilities, PID limit, CPU limit, and
memory limit. These controls are intentionally local/prod-like guardrails, not
a replacement for a target platform security policy.

Public host ports are parameterized for shared developer machines and CI
reruns. For example, `REPORT_FORGE_HOST_PORT=4400 docker compose up -d --build`
keeps the app listening on container port `4000` while publishing it on host
port `4400`.

## Runtime Configuration

Important environment variables include:

- `DATABASE_URL`
- `REPORT_FORGE_DB_HOST`
- `REPORT_FORGE_DB_PORT`
- `REPORT_FORGE_DB_NAME`
- `REPORT_FORGE_DB_USER`
- `REPORT_FORGE_DB_PASSWORD`
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
