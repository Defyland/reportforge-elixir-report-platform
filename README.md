# ReportForge

ReportForge is an Elixir-based reporting platform for finance and operations teams that need large CSV, JSON, and ZIP exports without blocking transactional systems.

> Status: executable slice with PostgreSQL-backed runtime, local and S3-compatible artifact storage, Oban-backed async execution, persistent audit logs, recurring cleanup jobs, and request-to-worker trace correlation. The repository now includes an HTTP API, tenant API keys, asynchronous report execution with signed streaming or presigned-redirect downloads, transactional metadata persistence, OpenTelemetry spans with OTLP export proof, telemetry-derived metrics, request tests, operational docs, and CI scaffolding. Production metric export, deployment-specific secret backends, and environment-specific infrastructure remain the main next steps.

Spec-driven evidence:
[senior readiness spec](./docs/spec-driven/senior-readiness-spec.md),
[implementation plan](./docs/spec-driven/implementation-plan.md),
[verification report](./docs/spec-driven/verification-report.md), and
[engineering case study](./docs/engineering-case-study.md).

Gap audit and remaining work: [docs/implementation-plan.md](./docs/implementation-plan.md)

## What is this product?

ReportForge is the backend service behind bulk financial reporting workflows such as cash-position snapshots, ledger summaries, and invoice audits. It accepts report requests, deduplicates repeated submissions, runs the generation pipeline asynchronously, records lifecycle events, and exposes signed download URLs for the resulting artifacts.

## Problem it solves

Financial exports are expensive because they combine wide datasets, tenant isolation rules, long-running queries, and large file generation. In many systems those exports either run inline and hurt the main application or they are pushed to ad-hoc batch code with weak observability and poor retry semantics.

ReportForge solves that by making report generation explicit:

- asynchronous report creation with lifecycle tracking
- tenant-scoped API key authentication
- idempotency keys and fingerprint-based deduplication
- signed download URLs with expiry
- event history for each report request
- operational endpoints, metrics, and failure-oriented documentation

Product detail lives in [docs/product/problem.md](./docs/product/problem.md),
[docs/product/use-cases.md](./docs/product/use-cases.md),
[docs/product/non-goals.md](./docs/product/non-goals.md), and
[docs/product/roadmap.md](./docs/product/roadmap.md).

## Target users

- treasury and finance operations teams exporting balance and ledger views
- internal data operations teams handling audit and reconciliation flows
- platform engineers who need a reference backend for async export orchestration
- support and reliability teams investigating delayed or failed report runs

Persona detail lives in [docs/product/personas.md](./docs/product/personas.md).

## Main features

- tenant registration with bootstrap API keys
- API-key-authenticated report creation and lookup
- async execution pipeline backed by PostgreSQL state and Oban
- `cash_position`, `ledger_summary`, and `invoice_audit` templates
- CSV, JSON, and ZIP output generation
- report cancellation, retry, progress, and event history
- signed artifact downloads with TTL enforcement
- persistent audit logs for privileged and report-sensitive actions
- recurring artifact-expiry cleanup and tenant-retention deletion jobs
- Prometheus-style metrics, request IDs, correlation IDs, and OpenTelemetry trace IDs

## Architecture overview

The current implementation is a lightweight Elixir service built with Bandit and Plug instead of a full Phoenix stack. That keeps the first executable slice small while still exposing a realistic HTTP contract and async orchestration behavior.

- `ReportForgeWeb.Router` is the HTTP edge
- `ReportForge.Identity` owns tenant registration and API-key authentication
- `ReportForge.Reports` owns report lifecycle, deduplication, and signed artifacts
- `ReportForge.Audit` persists sensitive operational actions for later review
- `ReportForge.Maintenance` owns recurring cleanup and retention workflows
- `ReportForge.Repo` persists organizations, API keys, reports, events, and artifacts in PostgreSQL
- `ReportForge.ArtifactStorage` stores generated artifact bytes outside PostgreSQL while keeping metadata in the database
- `ReportForge.Oban` schedules durable report jobs backed by PostgreSQL
- `ReportForge.Telemetry` emits domain/runtime events consumed by `ReportForge.Metrics`

Architecture detail lives in [docs/architecture/overview.md](./docs/architecture/overview.md), [docs/architecture/c4-context.md](./docs/architecture/c4-context.md), [docs/architecture/c4-container.md](./docs/architecture/c4-container.md), [docs/architecture/module-boundaries.md](./docs/architecture/module-boundaries.md), [docs/architecture/deployment-view.md](./docs/architecture/deployment-view.md), [docs/architecture/large-report-pipeline.md](./docs/architecture/large-report-pipeline.md), and [docs/diagrams/system-context.md](./docs/diagrams/system-context.md).

## Tech stack

| Component | Current choice | Planned upgrade path |
| --- | --- | --- |
| HTTP server | Bandit + Plug | Phoenix API surface if the repo grows into richer auth/admin flows |
| Language | Elixir 1.17 | Elixir remains the primary platform |
| Async execution | Oban backed by PostgreSQL | tune queues, retries, recurring jobs, and backoff policies as workload grows |
| Persistence | PostgreSQL with indexes, constraints, transactional state, and audit records | extend schema for archival and object-storage workflows |
| Artifact delivery | signed streaming downloads from local object storage or presigned S3/MinIO redirects with PostgreSQL metadata | production storage integration tests and bucket lifecycle policies |
| Observability | Logger, request IDs, correlation IDs, OpenTelemetry traces with OTLP export proof, `:telemetry` events, Prometheus text metrics, Grafana JSON | collector deployment wiring and richer dashboards |
| Load testing | k6 scripts and benchmark plan | captured results under reproducible environments |

## Domain model

Core entities:

- `Organization`: tenant boundary, retention policy, and auth scope
- `ApiKey`: tenant credential with prefix, hashed secret, and revocation state
- `Report`: async export aggregate with lifecycle, filters, and artifact metadata
- `ReportEvent`: immutable lifecycle event stream for a report request
- `Artifact`: signed downloadable output metadata persisted in PostgreSQL, with binary bytes stored through the active artifact-storage adapter

See [docs/architecture/domain-model.md](./docs/architecture/domain-model.md),
[docs/domain/glossary.md](./docs/domain/glossary.md),
[docs/domain/bounded-contexts.md](./docs/domain/bounded-contexts.md),
[docs/domain/aggregates.md](./docs/domain/aggregates.md),
[docs/domain/invariants.md](./docs/domain/invariants.md), and
[docs/domain/state-machines.md](./docs/domain/state-machines.md) for domain
language, invariants, and lifecycle ownership.

## API documentation

The versioned HTTP contract is defined in [openapi.yaml](./openapi.yaml).

Supporting API docs:

- [docs/api/http-examples.md](./docs/api/http-examples.md)
- [docs/api/error-format.md](./docs/api/error-format.md)

Implemented endpoints:

- `POST /api/v1/organizations`
- `GET /api/v1/organizations/me`
- `GET /api/v1/api-keys`
- `POST /api/v1/api-keys`
- `DELETE /api/v1/api-keys/{id}`
- `GET /api/v1/reports`
- `POST /api/v1/reports`
- `GET /api/v1/reports/{id}`
- `GET /api/v1/reports/{id}/events`
- `GET /api/v1/reports/{id}/download`
- `POST /api/v1/reports/{id}/cancel`
- `POST /api/v1/reports/{id}/retry`
- `GET /downloads/{token}`
- `GET /healthz`
- `GET /readyz`
- `GET /metrics`

## Async or event architecture

ReportForge treats report generation as an explicit asynchronous workflow:

1. `POST /api/v1/reports` records a queued report and a `report.requested` event.
2. An Oban job transitions the report to `running`.
3. The generator emits progress events as it simulates query completion and artifact staging.
4. The report transitions to `succeeded`, `failed`, or `cancelled`.
5. Successful runs issue a signed artifact URL with expiry metadata.

The lifecycle sequence is documented in [docs/diagrams/report-lifecycle-sequence.md](./docs/diagrams/report-lifecycle-sequence.md), the large-report pipeline constraints are documented in [docs/architecture/large-report-pipeline.md](./docs/architecture/large-report-pipeline.md), and versioned lifecycle event expectations are documented in [docs/events/README.md](./docs/events/README.md). The event docs define the future stream-first contract but do not implement new exporters.

## Database design

The current executable slice now runs on PostgreSQL and uses transactional persistence in the main request path:

- `organizations`, `api_keys`, `reports`, `report_events`, `report_artifacts`, and `audit_logs`
- unique constraints on tenant slug, API key prefix, and report idempotency keys
- fingerprint indexes to support deduplication
- event ordering per report
- cleanup indexes and scheduled retention workflows for reports and artifacts

See [docs/architecture/database-design.md](./docs/architecture/database-design.md).

## Testing strategy

The current test suite covers:

- organization registration and API-key authentication
- report idempotency and deduplication
- successful artifact creation and signed downloads
- failure simulation for upstream timeouts
- request-level auth and tenant isolation
- report event visibility and lifecycle assertions
- audit persistence for tenant bootstrap, key management, downloads, and report mutations
- retention-job and artifact-cleanup execution through Oban
- real MinIO integration for the S3-compatible storage adapter
- production-like smoke validation through Docker Compose

The next phases should add more recovery scenarios around retries, cancellations, queue backpressure, and dependency outages.

## Performance benchmarks

The repository ships benchmark planning and k6 scenarios for smoke, load, stress, and spike profiles.

- baseline plan: [benchmarks/baseline.md](./benchmarks/baseline.md)
- methodology: [docs/benchmarks/methodology.md](./docs/benchmarks/methodology.md)
- results status: [docs/benchmarks/results-status.md](./docs/benchmarks/results-status.md)
- results folder: [benchmarks/results/README.md](./benchmarks/results/README.md)

The current slice now has a first measured benchmark capture under [benchmarks/results/2026-05-29](./benchmarks/results/2026-05-29/README.md), including a default-limit load failure mode and a benchmark-tuned profile.

## Observability

Operational visibility included in this slice:

- structured JSON log bodies through `ReportForge.Observability`
- `request_id` and `correlation_id` on every HTTP response
- `traceparent` and `meta.trace_id` on every HTTP response
- async trace propagation from request spans into report worker spans
- `:telemetry` events for HTTP requests, report creation/completion/retry, and cleanup
- per-request metrics and report counters derived into `/metrics`
- `healthz` and `readyz` probes
- report event timelines for operator debugging

The next observability phase should add richer histograms and connect the shipped OTLP instrumentation to the target deployment collector.

Current observability notes:

- [docs/architecture/observability.md](./docs/architecture/observability.md)
- [docs/architecture/grafana-dashboard.json](./docs/architecture/grafana-dashboard.json)

## Security considerations

- every authenticated API is scoped by tenant API key
- secrets are stored as SHA-256 digests, not plain text
- signed artifact URLs expire after a configurable TTL
- signing secrets can be sourced from `SIGNING_SECRET` or `SIGNING_SECRET_FILE`
- rate limiting protects public organization creation and tenant read/write traffic
- request validation rejects unsupported template, format, and payload shapes
- tenant isolation is enforced across report reads, events, and downloads
- privileged actions such as key issuance, key revocation, report retry, cancellation, and downloads are recorded in persistent audit logs
- future phases can move runtime secrets to an external managed secret store and add first-class key rotation workflows when the deployment target requires it

Security detail:

- [docs/architecture/threat-model.md](./docs/architecture/threat-model.md)
- [docs/security/threat-model.md](./docs/security/threat-model.md)
- [docs/security/authorization-matrix.md](./docs/security/authorization-matrix.md)
- [docs/security/data-classification.md](./docs/security/data-classification.md)
- [docs/security/secrets.md](./docs/security/secrets.md)
- [docs/security/abuse-cases.md](./docs/security/abuse-cases.md)
- [docs/api/authorization-matrix.md](./docs/api/authorization-matrix.md)
- [docs/runbooks/report-artifact-exposure.md](./docs/runbooks/report-artifact-exposure.md)

## Trade-offs and decisions

- The current HTTP layer uses Bandit + Plug instead of Phoenix because the first vertical slice benefits more from small surface area than from framework breadth.
- PostgreSQL-backed state raises the local setup bar slightly, but it gives the slice transactional correctness and durable read models now.
- Oban covers report execution, transient failure retries with backoff, and recurring cleanup; queue partitioning is still intentionally minimal in this slice.
- ZIP exports are modeled early because packaging multiple views is central to the product story.

The main decisions are recorded in:

- [docs/adr/0001-plug-first-executable-slice.md](./docs/adr/0001-plug-first-executable-slice.md)
- [docs/adr/0002-deduplication-and-signed-downloads.md](./docs/adr/0002-deduplication-and-signed-downloads.md)
- [docs/adr/0003-task-supervisor-before-oban.md](./docs/adr/0003-task-supervisor-before-oban.md)
- [docs/adr/0004-adopt-oban-for-durable-execution.md](./docs/adr/0004-adopt-oban-for-durable-execution.md)
- [docs/adr/0005-artifact-storage-boundary-and-retry-policy.md](./docs/adr/0005-artifact-storage-boundary-and-retry-policy.md)
- [docs/adr/0006-stream-first-before-platform-complexity.md](./docs/adr/0006-stream-first-before-platform-complexity.md)

Scalability and cost trade-offs are documented in
[docs/scalability.md](./docs/scalability.md) and
[docs/operational-cost.md](./docs/operational-cost.md).

## How to run locally

Run the API directly with Mix:

```sh
bash scripts/start_local_postgres.sh
REPORT_FORGE_DB_PORT=55432 mix setup
REPORT_FORGE_DB_PORT=55432 mix run --no-halt
```

The service listens on `http://localhost:4000` by default. Override with environment variables:

```sh
PORT=4100 BASE_URL=http://localhost:4100 REPORT_FORGE_DB_PORT=55432 mix run --no-halt
```

Artifact storage defaults to the local adapter. Use the S3-compatible adapter for AWS S3 or MinIO:

```sh
REPORT_FORGE_ARTIFACT_STORAGE_ADAPTER=minio \
REPORT_FORGE_S3_BUCKET=reportforge-artifacts \
REPORT_FORGE_S3_ENDPOINT=http://localhost:9000 \
REPORT_FORGE_S3_ACCESS_KEY_ID=minioadmin \
REPORT_FORGE_S3_SECRET_ACCESS_KEY=minioadmin \
REPORT_FORGE_S3_FORCE_PATH_STYLE=true \
REPORT_FORGE_DB_PORT=55432 \
mix run --no-halt
```

For AWS S3, use `REPORT_FORGE_ARTIFACT_STORAGE_ADAPTER=s3`, set `REPORT_FORGE_S3_REGION`, omit the MinIO endpoint unless using a custom endpoint, and provide `REPORT_FORGE_S3_SECRET_ACCESS_KEY` or `REPORT_FORGE_S3_SECRET_ACCESS_KEY_FILE`.

Or build and run the container:

```sh
docker build -t reportforge .
docker run --rm -p 4000:4000 reportforge
```

Run the production-like local stack:

```sh
docker compose up -d --build
BASE_URL=http://localhost:4000 bash scripts/smoke.sh
```

If port `4000` is already in use, run the app on another host port without
changing the container port:

```sh
REPORT_FORGE_HOST_PORT=4400 docker compose up -d --build
BASE_URL=http://localhost:4400 bash scripts/smoke.sh
```

The stack includes PostgreSQL, MinIO, ReportForge, OpenTelemetry Collector,
Prometheus, and Grafana. ReportForge migrations run through a one-shot
`reportforge-migrate` service before the API starts.

- API: `http://localhost:4000`
- MinIO console: `http://localhost:9001`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

## How to run tests

Run the Elixir suite:

```sh
bash scripts/start_local_postgres.sh
REPORT_FORGE_DB_PORT=55432 mix test
```

Run the database integration tests with a local ephemeral PostgreSQL instance:

```sh
bash scripts/start_local_postgres.sh
REPORT_FORGE_DB_PORT=55432 mix ecto.create
REPORT_FORGE_DB_PORT=55432 mix ecto.migrate
REPORT_FORGE_DB_PORT=55432 mix test --only db
```

Run the full repository checks:

```sh
REPORT_FORGE_DB_PORT=55432 mix ci
```

Validate the OpenAPI contract:

```sh
npx @redocly/cli@latest lint openapi.yaml
```

## Failure scenarios

The repository explicitly models and documents these scenarios:

- duplicate report creation with the same idempotency key
- duplicate report submission via fingerprint-equivalent payloads
- simulated upstream source timeouts
- simulated object-storage write failures
- signed artifact URL expiry
- tenant attempts to read another tenant's report
- rate-limited organization creation or report submission bursts
- cancellation during queued or running work
- retry of terminal reports after failure or cancellation

Operational guidance lives in [docs/runbooks/common-issues.md](./docs/runbooks/common-issues.md). Failure drills live in [docs/runbooks/failure-drills.md](./docs/runbooks/failure-drills.md).

## Roadmap

1. Phase 1: executable HTTP slice with auth, async report lifecycle, signed downloads, tests, and docs.
2. Phase 2: PostgreSQL schema, durable report state, and OpenTelemetry request/worker trace correlation.
3. Phase 3: Oban jobs, scheduled reports, cancellation safety, and persistence-backed retries.
4. Phase 4: richer telemetry metrics, deployment collector integration, and key-rotation workflows.
5. Phase 5: managed deployment target, read-replica-aware exporters, XLSX/PDF adapters, and multi-file bundle templates.
