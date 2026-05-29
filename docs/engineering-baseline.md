# ReportForge Engineering Baseline

This repository targets the portfolio-wide standard from [`specs/general-project-spec.md`](../../specs/general-project-spec.md) and translates it into ReportForge-specific engineering outcomes.

## Mandatory outcomes

- product-grade `README.md` with product and engineering sections
- versioned `openapi.yaml`
- `docs/adr/`, `docs/api/`, `docs/architecture/`, `docs/benchmarks/`, `docs/diagrams/`, and `docs/runbooks/`
- CI workflow for formatting, linting, tests, Docker validation, and OpenAPI validation
- tests across auth, request flow, lifecycle, and failure scenarios
- Prometheus-style metrics, request IDs, correlation IDs, and health probes
- benchmark plan and k6 scenarios

## ReportForge-specific emphasis

- report idempotency and fingerprint-based deduplication
- bounded async lifecycle with progress and operator-visible events
- signed artifact downloads and expiry semantics
- isolation of tenant data across report reads and artifacts
- explicit migration path from the current PostgreSQL artifact adapter toward object storage, managed secrets, and cleanup workflows

## Current slice boundary

The current slice is intentionally infrastructure-light:

- PostgreSQL-backed storage for the main runtime path
- Oban-backed durable execution
- signed artifact delivery through a storage boundary backed by PostgreSQL today instead of S3 or MinIO

Those are deliberate trade-offs to keep artifact storage simple while still making the future object-storage migration a localized adapter change.

## Review note

The latest senior-oriented technical review for this slice lives in [docs/architecture/senior-technical-assessment.md](./architecture/senior-technical-assessment.md).
