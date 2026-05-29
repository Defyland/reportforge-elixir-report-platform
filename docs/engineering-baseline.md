# ReportForge Engineering Baseline

This repository targets the portfolio-wide standard from [`specs/general-project-spec.md`](../../specs/general-project-spec.md) and translates it into ReportForge-specific engineering outcomes.

## Mandatory outcomes

- product-grade `README.md` with product and engineering sections
- versioned `openapi.yaml`
- `docs/adr/`, `docs/api/`, `docs/architecture/`, `docs/benchmarks/`, `docs/diagrams/`, and `docs/runbooks/`
- CI workflow for formatting, linting, tests, Docker validation, OpenAPI validation, real MinIO integration, and Compose smoke validation
- production-like Docker Compose stack with executable smoke validation
- tests across auth, request flow, lifecycle, and failure scenarios
- Prometheus-style metrics, request IDs, correlation IDs, and health probes
- benchmark plan and k6 scenarios

## ReportForge-specific emphasis

- report idempotency and fingerprint-based deduplication
- bounded async lifecycle with progress and operator-visible events
- signed artifact downloads and expiry semantics
- isolation of tenant data across report reads and artifacts
- explicit runtime path across local, S3/MinIO, managed secrets, and cleanup workflows

## Current slice boundary

The current slice is intentionally infrastructure-light:

- PostgreSQL-backed storage for the main runtime path
- local object storage for generated artifact bytes by default
- S3-compatible object storage for AWS S3 or MinIO deployments
- Oban-backed durable execution
- signed streaming artifact delivery through a storage boundary
- Prometheus alert rules, Grafana provisioning, and OTel collector wiring for local operational proof

Those are deliberate trade-offs to keep artifact storage production-shaped while preserving a lightweight local developer path.

## Review note

The latest senior-oriented technical review for this slice lives in [docs/architecture/senior-technical-assessment.md](./architecture/senior-technical-assessment.md).
