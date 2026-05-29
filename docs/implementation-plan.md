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
| CI workflow | Done | [.github/workflows/ci.yml](../.github/workflows/ci.yml), local `mix ci` pass, explicit jobs for lint/format/tests/security/OpenAPI/coverage/docker | Watch for the first green GitHub Actions run after push |
| Unit / request / auth / failure tests | Done | [test](../test/), local `mix test` pass | Expand coverage as new runtime layers land |
| Database tests | Done | [ReportForge.Repo](../../lib/report_forge/repo.ex), [migrations](../../priv/repo/migrations/), [test/report_forge/persistence_test.exs](../../test/report_forge/persistence_test.exs), [test/report_forge/audit_test.exs](../../test/report_forge/audit_test.exs), [test/report_forge/maintenance/cleanup_worker_test.exs](../../test/report_forge/maintenance/cleanup_worker_test.exs), local `mix test --only db` and `mix ci` pass with ephemeral PostgreSQL | Expand coverage when object storage or archival flows land |
| Messaging tests | Done | [test/report_forge/reports/worker_test.exs](../../test/report_forge/reports/worker_test.exs), [test/report_forge/reports_test.exs](../../test/report_forge/reports_test.exs), [test/report_forge/maintenance/cleanup_worker_test.exs](../../test/report_forge/maintenance/cleanup_worker_test.exs) cover enqueueing, draining, retry/cancel flow, and recurring async cleanup | Add broker-specific tests only if a broker is introduced later |
| Performance tests | Done | [benchmarks](../benchmarks/), [benchmarks/baseline.md](../benchmarks/baseline.md), and [benchmarks/results/2026-05-29](../benchmarks/results/2026-05-29/README.md) | Rerun under Docker or CI once available |
| Observability baseline | Done | structured logs, request/correlation IDs, `/metrics`, health/readiness probes, Grafana dashboard, OpenTelemetry request + worker traces, persisted trace metadata, and OTLP export proof in [test/report_forge/otlp_export_test.exs](../../test/report_forge/otlp_export_test.exs) | Evolve metric families as the product grows |
| Security baseline | Done | threat model, authorization matrix, API-key auth, rate limiting, input validation, tenant isolation, env-based secret management, persistent audit logs, local Sobelow pass | Add external secret-manager integration only if the deployment target requires it |
| Messaging baseline topology | Done | current async architecture uses PostgreSQL + Oban rather than RabbitMQ or another external broker, so the broker-topology subsection of the spec is not applicable to the shipped runtime | If a broker is introduced later, add exchanges, queues, DLQ, retry, idempotency, ack, and correlation-ID documentation plus tests |
| Data and transaction baseline | Done | [docs/architecture/database-design.md](./architecture/database-design.md), [lib/report_forge/identity.ex](../../lib/report_forge/identity.ex), [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex), [lib/report_forge/audit.ex](../../lib/report_forge/audit.ex), [lib/report_forge/maintenance.ex](../../lib/report_forge/maintenance.ex), migrations, transaction test rollback proof | Extend the schema only as later phases introduce object storage or archival flows |
| Commit history standard | Done | [git log](../../.git) on branch `codex/reportforge-implementation` now shows atomic Conventional Commits for tooling, core runtime, and documentation/benchmark evidence | Keep future changes equally atomic |
| Docker build validation | Done | [.github/workflows/ci.yml](../.github/workflows/ci.yml) includes an explicit `docker build` job and [Dockerfile](../Dockerfile) is versioned | Local ad-hoc proof still depends on a running Docker daemon |

## Remaining work by phase

## Phase 1.1: close documentation and structural gaps

Status: completed for the current slice.

- add explicit threat model
- add authorization matrix
- add observability subsystem notes
- add Grafana dashboard definition
- add auditable requirement-check script and wire it into CI

## Phase 1.2: executable quality gates

Status: completed for the repository requirements.

Completed evidence:

- `mix compile` passes
- `mix test` passes
- `mix ci` passes
- `bash scripts/validate_requirements.sh` passes
- `npx @redocly/cli@latest lint openapi.yaml` passes with warnings only

Remaining work:

- no spec-blocking work remains in this phase; future remote CI runs will provide extra operational confidence

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

Status: completed for the current slice.

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

Remaining work:

- define broker topology only if RabbitMQ or another broker is adopted later

## Phase 4: observability parity with the spec

Status: completed for the current slice.

Completed evidence:

- OpenTelemetry SDK and OTLP exporter are configured in [config/config.exs](../config/config.exs) and [mix.exs](../mix.exs)
- [lib/report_forge_web/request_context.ex](../../lib/report_forge_web/request_context.ex) now keeps a server span open for the entire HTTP request and returns `traceparent`
- [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex) and [lib/report_forge/reports/worker.ex](../../lib/report_forge/reports/worker.ex) propagate trace context into async execution
- [lib/report_forge/reports/report_event.ex](../../lib/report_forge/reports/report_event.ex) persists `trace_id` and `span_id` on lifecycle events
- request and worker trace assertions exist in [test/report_forge_web/router_test.exs](../../test/report_forge_web/router_test.exs) and [test/report_forge/reports/worker_test.exs](../../test/report_forge/reports/worker_test.exs)
- [test/report_forge/otlp_export_test.exs](../../test/report_forge/otlp_export_test.exs) validates OTLP trace export end-to-end against a local collector stub
- local `mix ci` passes with the tracing path enabled and `80.02%` total coverage

Remaining work:

- no spec-blocking work remains in this phase; richer dashboards and metric pipelines are optional future improvements

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

Status: completed for the current slice.

Completed evidence:

- [lib/report_forge/audit.ex](../../lib/report_forge/audit.ex), [lib/report_forge/audit/log.ex](../../lib/report_forge/audit/log.ex), and [priv/repo/migrations/20260529040000_add_audit_logs_and_cleanup_support.exs](../../priv/repo/migrations/20260529040000_add_audit_logs_and_cleanup_support.exs) persist durable audit records
- [lib/report_forge/identity.ex](../../lib/report_forge/identity.ex) and [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex) record tenant bootstrap, API-key management, report mutation, and download audit events
- [lib/report_forge/maintenance.ex](../../lib/report_forge/maintenance.ex), [lib/report_forge/maintenance/cleanup_worker.ex](../../lib/report_forge/maintenance/cleanup_worker.ex), and [config/config.exs](../config/config.exs) implement recurring artifact-expiry cleanup and tenant-retention deletion jobs
- [test/report_forge/audit_test.exs](../../test/report_forge/audit_test.exs) and [test/report_forge/maintenance/cleanup_worker_test.exs](../../test/report_forge/maintenance/cleanup_worker_test.exs) prove audit persistence and cleanup behavior
- [config/runtime.exs](../config/runtime.exs) supports `SIGNING_SECRET` and `SIGNING_SECRET_FILE`, and production now fails fast when neither is configured

Remaining work:

- no spec-blocking work remains in this phase; deployment-specific secret backends and rotation workflows are optional future hardening

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
- added [test/report_forge/otlp_export_test.exs](../../test/report_forge/otlp_export_test.exs) to prove OTLP trace export against a local collector stub
- split the work into atomic Conventional Commits on branch `codex/reportforge-implementation`

## Blockers that still prevent full completion

- none at the repository-spec level; the only remaining limitation observed locally is that ad-hoc `docker build` could not be executed without a running Docker daemon, even though CI already covers that validation

The repository now satisfies the current repository-level requirements in [`specs/general-project-spec.md`](../../specs/general-project-spec.md). Any remaining items in this plan are optional future hardening or infrastructure-specific enhancements, not spec blockers.
