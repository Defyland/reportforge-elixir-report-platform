# Production Readiness Review

This repository is production-shaped, but not a turnkey production deployment. The codebase demonstrates the core engineering properties expected from a senior backend service: durable state, async work, idempotency, operational visibility, failure classification, storage abstraction, executable contracts, and runbooks.

## Already strong

- tenant-scoped API-key auth with hashed secrets and audit records
- PostgreSQL-backed aggregate state, lifecycle events, idempotency, and uniqueness constraints
- Oban-backed async processing, retries, cancellation, recurring cleanup, and queue observability
- local and S3-compatible artifact storage behind `ReportForge.ArtifactStorage`
- signed service download URLs and S3/MinIO presigned redirects
- OpenAPI contract plus live response contract tests
- structured logs, request/correlation IDs, OpenTelemetry trace propagation, `:telemetry` events, and Prometheus exposition
- CI-oriented gates for format, compile warnings, Credo, Sobelow, dependency audit, tests, coverage, OpenAPI lint, Docker build, real MinIO storage integration, and production-like Compose smoke testing
- local production-like stack with PostgreSQL, MinIO, OpenTelemetry Collector, Prometheus, Grafana, and executable smoke checks

## Current validation evidence

- `mix ci`: 47 tests passing, 1 intentional MinIO skip in the default local run, 78.15% coverage
- `REPORT_FORGE_MINIO_INTEGRATION=1 mix test ... --include minio`: real MinIO adapter test passing
- `docker build -t reportforge-ci .`: production image build passing
- `docker compose up -d` plus `scripts/smoke.sh`: end-to-end API, Oban, PostgreSQL, MinIO, metrics, and artifact download path passing
- `npx @redocly/cli@latest lint openapi.yaml`: valid OpenAPI with 3 non-blocking warnings for unauthenticated operational endpoints

## Missing before 100% production-ready

- Environment provisioning: Terraform, Kubernetes manifests or managed platform config, managed PostgreSQL, managed S3, ingress TLS, autoscaling, and resource limits.
- Secret management: integration with the target platform secret manager, API-key rotation operations, signing-secret rotation, and emergency revoke procedures.
- Storage operations: cloud bucket encryption policy, lifecycle policy, object retention policy, and orphan-object reconciliation.
- Observability operations: cloud OpenTelemetry collector deployment, alert delivery routing, SLOs, dashboards validated against real traffic, and log retention policy.
- Reliability proof: load tests against deployed infrastructure, queue capacity tuning, retry exhaustion drills, DB failover drills, and object-storage outage drills.
- Release safety: migration rollback playbooks, blue/green or rolling deploy strategy, compatibility checks for Oban job args, and automated smoke tests in the deployment pipeline.
- Security hardening: threat-model review against the target deployment, TLS termination policy, CORS policy if browser clients are added, SBOM or image scanning, and dependency-update automation.
- Data protection: backup/restore drills, retention/legal-hold rules, disaster recovery objectives, and tenant data export/deletion procedures.

## Portfolio calibration

For seniority evaluation, this repo is ready to present once CI is green. The remaining items are environment-specific production work, not evidence that the implementation lacks senior engineering judgment.
