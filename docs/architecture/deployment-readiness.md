# Deployment Readiness

ReportForge needs an API process, Oban workers, PostgreSQL, and artifact storage. The current repository documents that shape without requiring cluster-specific manifests.

## Current posture

- PostgreSQL-backed API and worker state.
- Oban-backed durable execution.
- Health, readiness, metrics, traces, and structured logs.
- Local and S3-compatible artifact storage paths.
- Docker Compose and production-like smoke validation.
- Digest-pinned release image bases, non-root runtime user, readiness
  healthcheck, and Compose-level process hardening.
- Runtime database configuration through `config/runtime.exs`, including
  `DATABASE_URL` and `REPORT_FORGE_DB_*` support for release containers.
- One-shot `reportforge-migrate` Compose service before the long-lived API
  process starts.

## Deferred platform work

- Kubernetes and Helm are deferred until worker concurrency, queues, and storage credentials are stable.
- CDC and data-lake architecture are deferred; generated reports remain the product boundary.
- A managed secret store should replace local file or environment secrets for production.
