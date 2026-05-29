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
- CI-oriented gates for format, compile warnings, Credo, Sobelow, dependency audit, tests, coverage, OpenAPI lint, and Docker build

## Missing before 100% production-ready

- Environment provisioning: Terraform, Kubernetes manifests, managed PostgreSQL, managed S3/MinIO, ingress TLS, autoscaling, and resource limits.
- Secret management: integration with the target platform secret manager, API-key rotation operations, signing-secret rotation, and emergency revoke procedures.
- Storage operations: bucket encryption policy, lifecycle policy, object retention policy, orphan-object reconciliation, and container-backed S3/MinIO tests in CI.
- Observability operations: OpenTelemetry collector deployment, Prometheus scrape config, alert rules, SLOs, dashboards validated against real traffic, and log retention policy.
- Reliability proof: load tests against production-like infrastructure, queue capacity tuning, retry exhaustion drills, DB failover drills, and object-storage outage drills.
- Release safety: migration rollback playbooks, blue/green or rolling deploy strategy, compatibility checks for Oban job args, and release smoke tests.
- Security hardening: threat-model review against the target deployment, TLS termination policy, CORS policy if browser clients are added, SBOM or image scanning, and dependency-update automation.
- Data protection: backup/restore drills, retention/legal-hold rules, disaster recovery objectives, and tenant data export/deletion procedures.

## Portfolio calibration

For seniority evaluation, this repo is ready to present once the branch is pushed and CI is green. The remaining items are environment-specific production work, not evidence that the implementation lacks senior engineering judgment.
