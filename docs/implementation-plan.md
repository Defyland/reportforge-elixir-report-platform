# Full Requirements Implementation Plan

This document audits the current repository against [`specs/general-project-spec.md`](../../specs/general-project-spec.md), records what is already proven by repository evidence, and lists the remaining work required for full compliance.

## Status legend

- `Done`: repository evidence already proves the requirement
- `Partial`: some evidence exists, but the requirement is not fully proven yet
- `Missing`: no sufficient implementation evidence exists yet
- `Future phase`: intentionally deferred because the current slice does not yet include the required infrastructure

## Audit summary

| Area | Status | Current evidence | Remaining work |
| --- | --- | --- | --- |
| Mandatory repository structure | Done | [docs](./), [benchmarks](../benchmarks/) | Keep structure enforced in CI |
| README product + engineering sections | Done | [README.md](../README.md) | Keep updated as runtime evolves |
| OpenAPI contract | Done | [openapi.yaml](../openapi.yaml), local `redocly lint openapi.yaml` pass | Expand examples as endpoints evolve |
| API examples and error format docs | Done | [docs/api/http-examples.md](./api/http-examples.md), [docs/api/error-format.md](./api/error-format.md) | Keep synchronized with contract changes |
| ADRs and architecture docs | Done | [docs/adr](./adr/), [docs/architecture](./architecture/) | Keep ADRs synchronized with runtime changes |
| CI workflow | Done | [.github/workflows/ci.yml](../.github/workflows/ci.yml), local `mix ci` pass | Watch for the first green GitHub Actions run after push |
| Unit / request / auth / failure tests | Done | [test](../test/), local `mix test` pass | Expand coverage as new runtime layers land |
| Database tests | Done | [ReportForge.Repo](../../lib/report_forge/repo.ex), [migrations](../../priv/repo/migrations/), [test/report_forge/persistence_test.exs](../../test/report_forge/persistence_test.exs), [test/report_forge/audit_test.exs](../../test/report_forge/audit_test.exs), [test/report_forge/maintenance/cleanup_worker_test.exs](../../test/report_forge/maintenance/cleanup_worker_test.exs), local `mix test --only db` and `mix ci` pass with ephemeral PostgreSQL | Expand coverage when object storage or archival flows land |
| Messaging tests | Partial | Oban-backed async worker lifecycle tests exist, but no external broker topology exists | Add broker topology and messaging tests once RabbitMQ or equivalent exists |
| Performance tests | Done | [benchmarks](../benchmarks/), [benchmarks/baseline.md](../benchmarks/baseline.md), and [benchmarks/results/2026-05-29](../benchmarks/results/2026-05-29/README.md) | Rerun under Docker or CI once available |
| Observability baseline | Partial | metrics, request/correlation IDs, OpenTelemetry request + worker traces, persisted event trace metadata, dashboard JSON, local `mix ci` pass | Validate collector-backed export and move metrics to an official telemetry pipeline |
| Security baseline | Partial | API keys, rate limiting, validation, tenant isolation, threat model docs, persistent audit logs, runtime secret loading via env or `*_FILE`, local Sobelow pass | External managed secret integration and formal key-rotation workflows are still missing |
| Messaging baseline topology | Future phase | no broker yet | Define exchanges, queues, DLQ, retry, idempotency, and ack semantics when broker is introduced |
| Data and transaction baseline | Done | [docs/architecture/database-design.md](./architecture/database-design.md), [lib/report_forge/identity.ex](../../lib/report_forge/identity.ex), [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex), [lib/report_forge/audit.ex](../../lib/report_forge/audit.ex), [lib/report_forge/maintenance.ex](../../lib/report_forge/maintenance.ex), migrations, transaction test rollback proof | Extend the schema only as later phases introduce object storage or archival flows |
| Commit history standard | Partial | current local changes are not yet split into atomic commits | Finalize implementation with coherent Conventional Commit history |
| Docker build validation | Partial | [Dockerfile](../Dockerfile), CI workflow step exists | Local Docker daemon was unavailable, so runtime build proof is still missing |

## Remaining work by phase

## Phase 1.1: close documentation and structural gaps

Status: completed for the current slice.

- add explicit threat model
- add authorization matrix
- add observability subsystem notes
- add Grafana dashboard definition
- add auditable requirement-check script and wire it into CI

## Phase 1.2: executable quality gates

Status: completed locally, pending remote CI proof.

Completed evidence:

- `mix compile` passes
- `mix test` passes
- `mix ci` passes
- `bash scripts/validate_requirements.sh` passes
- `npx @redocly/cli@latest lint openapi.yaml` passes with warnings only

Remaining work:

- obtain a successful GitHub Actions run after push
- obtain a local or CI-backed Docker build result once a Docker daemon is available

## Phase 2: durable runtime

Status: completed for the current slice.

Completed evidence:

- `ReportForge.Application` now starts [ReportForge.Repo](../../lib/report_forge/application.ex)
- the main runtime path in [ReportForge.Identity](../../lib/report_forge/identity.ex) and [ReportForge.Reports](../../lib/report_forge/reports.ex) reads and writes PostgreSQL directly
- lifecycle events and artifacts are persisted transactionally
- request tests and dedicated DB tests both exercise the durable path
- local `mix ci` passes against an ephemeral PostgreSQL instance with `80.02%` coverage

Remaining work:

- extend the schema only when object-storage or archival requirements land

## Phase 3: durable async execution and messaging

Status: partially completed.

Completed evidence:

- [lib/report_forge/oban.ex](../../lib/report_forge/oban.ex) starts a dedicated Oban instance
- [lib/report_forge/application.ex](../../lib/report_forge/application.ex) supervises Oban in the main runtime
- [lib/report_forge/reports/worker.ex](../../lib/report_forge/reports/worker.ex) is now an `Oban.Worker`
- [priv/repo/migrations/20260529030000_add_oban_and_report_execution_jobs.exs](../../priv/repo/migrations/20260529030000_add_oban_and_report_execution_jobs.exs) installs Oban tables and report job tracking
- [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex) persists `execution_job_id` and wires create, cancel, and retry to durable jobs
- [lib/report_forge/maintenance/cleanup_worker.ex](../../lib/report_forge/maintenance/cleanup_worker.ex) runs recurring cleanup through Oban cron queues
- [test/report_forge/reports_test.exs](../../test/report_forge/reports_test.exs), [test/report_forge/reports/worker_test.exs](../../test/report_forge/reports/worker_test.exs), and [test/support/case.ex](../../test/support/case.ex) prove enqueueing and queue draining through Oban
- [test/report_forge/maintenance/cleanup_worker_test.exs](../../test/report_forge/maintenance/cleanup_worker_test.exs) proves artifact cleanup and retention deletion through Oban
- local `mix ci` passes with the Oban-backed execution path enabled

Required work:

- define broker topology if RabbitMQ is adopted
- add messaging tests for retry, DLQ, correlation propagation, and idempotency

Proof expected:

- worker modules backed by durable jobs
- broker topology docs under `docs/architecture/` or `docs/events/`
- automated tests for async failure scenarios

## Phase 4: observability parity with the spec

Status: partially completed in the current slice.

Completed evidence:

- OpenTelemetry SDK and OTLP exporter are configured in [config/config.exs](../config/config.exs) and [mix.exs](../mix.exs)
- [lib/report_forge_web/request_context.ex](../../lib/report_forge_web/request_context.ex) now keeps a server span open for the entire HTTP request and returns `traceparent`
- [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex) and [lib/report_forge/reports/worker.ex](../../lib/report_forge/reports/worker.ex) propagate trace context into async execution
- [lib/report_forge/reports/report_event.ex](../../lib/report_forge/reports/report_event.ex) persists `trace_id` and `span_id` on lifecycle events
- request and worker trace assertions exist in [test/report_forge_web/router_test.exs](../../test/report_forge_web/router_test.exs) and [test/report_forge/reports/worker_test.exs](../../test/report_forge/reports/worker_test.exs)
- local `mix ci` passes with the tracing path enabled and `80.02%` total coverage

Remaining work:

- validate collector-backed export in a running environment outside the local test suite
- export metrics to Prometheus through official telemetry integration
- validate Grafana dashboard panels against emitted runtime metrics

## Phase 5: performance evidence

Status: completed for the current slice.

Completed evidence:

- dated files now exist under [benchmarks/results/2026-05-29](../benchmarks/results/2026-05-29/README.md)
- the repository has measured `smoke`, `load`, `stress`, and `spike` against the PostgreSQL + Oban runtime
- the result set includes explicit `p50`, `p95`, and `p99` latency evidence
- the result set includes a default-limit load failure mode, a benchmark-tuned load pass, and CPU/RSS notes from a profiled spike run

Remaining work:

- rerun the suite under Docker or CI once a daemon-backed environment is available
- repeat after object storage and production telemetry export are added

## Phase 6: operational hardening

Status: partially completed in the current slice.

Completed evidence:

- [lib/report_forge/audit.ex](../../lib/report_forge/audit.ex), [lib/report_forge/audit/log.ex](../../lib/report_forge/audit/log.ex), and [priv/repo/migrations/20260529040000_add_audit_logs_and_cleanup_support.exs](../../priv/repo/migrations/20260529040000_add_audit_logs_and_cleanup_support.exs) persist durable audit records
- [lib/report_forge/identity.ex](../../lib/report_forge/identity.ex) and [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex) record tenant bootstrap, API-key management, report mutation, and download audit events
- [lib/report_forge/maintenance.ex](../../lib/report_forge/maintenance.ex), [lib/report_forge/maintenance/cleanup_worker.ex](../../lib/report_forge/maintenance/cleanup_worker.ex), and [config/config.exs](../config/config.exs) implement recurring artifact-expiry cleanup and tenant-retention deletion jobs
- [test/report_forge/audit_test.exs](../../test/report_forge/audit_test.exs) and [test/report_forge/maintenance/cleanup_worker_test.exs](../../test/report_forge/maintenance/cleanup_worker_test.exs) prove audit persistence and cleanup behavior
- [config/runtime.exs](../config/runtime.exs) supports `SIGNING_SECRET` and `SIGNING_SECRET_FILE`, and production now fails fast when neither is configured

Remaining work:

- integrate an external managed secret store beyond env and mounted secret files
- add explicit key-rotation workflows and operational proof for secret rollover
- keep expanding outage/recovery runbooks as storage and telemetry dependencies grow

## What was executed in this turn

- enabled a working local Elixir toolchain path and executed the actual project gates
- fixed compile-time defects in ID generation and rate limiting
- formatted the codebase and added a project-level Credo configuration
- fixed OpenAPI lint errors and improved contract metadata
- made `mix ci` pass locally, including tests, coverage, Credo, Sobelow, and dependency audit
- added PostgreSQL/Ecto scaffolding with migrations, schemas, a repo, and database integration tests
- moved the main runtime path from in-memory domain state to PostgreSQL-backed identity and report flows
- validated database migrations and `:db` tests against an ephemeral local PostgreSQL instance
- adopted Oban for durable report execution, persisted job references on reports, and migrated create/cancel/retry flows to durable jobs
- removed the obsolete in-memory task registry from the supervised runtime
- added OpenTelemetry request spans, async trace propagation, persisted event trace metadata, and response `traceparent` support
- added missing security and observability documents
- added a Grafana dashboard definition
- added an automated baseline validation script and CI step
- extended tests with async lifecycle, validation, cancellation/retry, and rate-limit coverage
- updated README, diagrams, runbooks, ADRs, and the implementation plan to reflect the PostgreSQL + Oban runtime that is actually shipping
- ended this gate at `80.02%` total coverage with the Oban path enabled
- added audit-style structured log events for tenant and report actions
- reran the full gate with `mix ci`, `bash scripts/validate_requirements.sh`, and `redocly lint`, ending with `26` tests passing, `80.02%` total coverage, and `3` non-blocking OpenAPI warnings
- captured dated benchmark evidence under [benchmarks/results/2026-05-29](../benchmarks/results/2026-05-29/README.md), including a rate-limit failure mode and a benchmark-tuned passing load profile
- made tenant rate limits configurable by environment so benchmark runs can isolate queue and persistence behavior without changing product defaults
- added persistent audit storage for privileged tenant and report actions, backed by dedicated tests
- added recurring artifact-expiry cleanup and tenant-retention deletion through Oban, backed by dedicated tests
- added runtime signing-secret support via `SIGNING_SECRET` or `SIGNING_SECRET_FILE`

## Blockers that still prevent full completion

- collector-backed telemetry export is configured but not yet proven in a running environment
- external managed secret integration and formal key-rotation workflows are still absent
- local Docker build validation could not be proven because the Docker daemon was not running

The repository is materially closer to the full spec now, but it is not yet fully compliant until the future-phase items above are implemented and verified.
