# ReportForge Engineering Baseline

This repository follows the initiative-wide standards below.

## Mandatory outcomes

- Product-grade `README.md` with product and engineering sections
- `openapi.yaml` once the HTTP surface exists
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- atomic Conventional Commit history
- GitHub Actions for lint, tests, security, build, coverage, and OpenAPI validation
- observability with structured logs, metrics, traces, request IDs, and readiness endpoints
- documented k6 performance baselines

## ReportForge-specific emphasis

- streaming exporters that avoid loading full datasets into memory
- explicit report lifecycle, cancellation, retry, and expiry semantics
- idempotency keys and fingerprint-based deduplication
- object-storage upload and signed-download flows with retry safety
- read-replica-aware query strategy for heavy report generation
- progress telemetry and operational visibility for long-running jobs

## Phase 0 boundary

This repository intentionally stops before scaffolding Phoenix, background jobs, or storage integrations. The goal of this phase is only to lock scope and standards.
