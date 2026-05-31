# Senior Readiness Spec

This spec applies the shared repository-root standards from:

- `../../../specs/general-project-spec.md`
- `../../../specs/senior-engineering-rubric.md`
- `../../../specs/spec-driven-senior-quality.md`

ReportForge is considered senior/tech-lead portfolio-ready when the repository
proves product thinking, domain modeling, consistency, security,
observability, performance discipline, operational cost awareness, and honest
deferred scope.

## Product Bar

ReportForge must read as a product for finance and operations teams that need
large exports without blocking transactional systems. The docs must name users,
workflow, non-goals, and business value.

## Domain Bar

The domain must describe organizations, API keys, reports, lifecycle events,
artifacts, retention, idempotency, and state transitions using the same language
as the code and tests.

## Architecture Bar

The architecture must explain why this is a modular Elixir API with Plug,
Bandit, Ecto, PostgreSQL, Oban, and storage adapters. It must document
boundaries, sequence flows, deployment view, and rejected alternatives.

## API Bar

The API must provide OpenAPI, versioned endpoints, API-key auth, standardized
errors, examples, idempotent report creation, and failure examples.

Report collections must use paginated report listings with an opaque cursor and
an explicit maximum page size. Response schemas must declare required fields so
contract tests reject missing `data`, `meta`, report fields, or unexpected
response properties.

## Data and Consistency Bar

The docs must explain transaction boundaries, unique constraints, indexes,
foreign keys, isolation assumptions, migration strategy, rollback strategy, and
which flows must remain strongly consistent.

No external side effects inside long database transactions: file writes, S3
PUT/DELETE calls, and presigned storage work must not run while the report row
is locked. Report completion must stage storage outside the short report-state
transactions and compensate uploaded artifacts if finalization no longer owns a
running report.

## Security Bar

Security evidence must cover threat model, financial export abuse cases,
authorization matrix, tenant isolation, API keys, signed URLs, retention,
secrets, rate limiting, audit logs, and residual risks.

## Observability Bar

The repository must expose or document structured logs, request IDs,
correlation IDs, traces, metrics, health, readiness, Prometheus, Grafana,
alerts, and runbooks.

## Performance Bar

Benchmarks must include smoke, load, stress, spike, p50/p95/p99, throughput,
error rate, and resource notes. Claims must point to measured results or be
marked as planned.

## Scalability Bar

The docs must name hot paths, read-heavy and write-heavy operations, fastest
growing tables, queue buildup risks, hot tenant keys, horizontal scale paths,
and consistency boundaries.

The local rate limiter must be a bounded local rate limiter with expiry pruning,
capacity limits, serialized new-bucket admission, atomic bucket increments, and
a documented multi-node replacement path. Production evaluation should see a
clear boundary rather than an unbounded process map.

## Operational Cost Bar

The repository must document infrastructure components, debugging complexity,
deployment complexity, backup/retention cost, monitoring burden, vendor lock-in,
and simpler alternatives rejected.

## Maintainability Bar

The codebase must expose clear module boundaries, scripts, seed data, error
payloads, test strategy, extension points, and ADRs for the main trade-offs.

## Readability Bar

Docs, tests, and code must use domain nouns such as `Report`, `ReportEvent`,
`Artifact`, `Organization`, `idempotency_key`, `signed URL`, and `retention`.

## Test and CI Bar

CI must cover format, compile warnings, lint, security scan, dependency audit,
migrations, tests, coverage, database integration, OpenAPI, Docker build, MinIO
integration, markdown, and Compose smoke validation.

## Evidence Matrix

| Criterion | Evidence | Status | Notes |
| --- | --- | --- | --- |
| Product problem and users are explicit | `README.md`, `docs/product/problem.md`, `docs/product/personas.md` | Done | Finance exports are the core workflow. |
| Product non-goals and roadmap are explicit | `docs/product/non-goals.md`, `docs/product/roadmap.md` | Done | Kubernetes/data lake/exporters are scoped honestly. |
| Domain glossary exists | `docs/domain/glossary.md` | Done | Terms match code modules and API payloads. |
| Aggregates and invariants are documented | `docs/domain/aggregates.md`, `docs/domain/invariants.md` | Done | Includes tenant ownership, idempotency, artifact TTL, and lifecycle. |
| State machine is documented and tested | `docs/domain/state-machines.md`, `test/report_forge/reports/worker_test.exs` | Done | Worker test validates canonical lifecycle events. |
| Architecture boundaries are explicit | `docs/architecture/module-boundaries.md`, `docs/architecture/overview.md` | Done | Web, Identity, Reports, Storage, Runtime, and Ops boundaries. |
| Deployment shape is documented | `docs/architecture/deployment-view.md`, `docker-compose.yml` | Done | Compose proves API, DB, Oban, MinIO, OTel, Prometheus, Grafana. |
| API contract exists | `openapi.yaml`, `docs/api/http-examples.md`, `test/report_forge_web/openapi_contract_test.exs` | Done | Contract is linted and request-tested. |
| Data consistency is documented | `docs/architecture/database-design.md`, `docs/scalability.md` | Done | Constraints, indexes, transactions, and strong consistency boundaries. |
| Active report dedupe is scoped | `priv/repo/migrations/20260531010000_scope_report_fingerprint_dedupe_to_active_reports.exs`, `test/report_forge/reports_test.exs` | Done | Uses a partial active-report fingerprint index so failed/cancelled reports do not block legitimate retries. |
| Storage side effects are outside long transactions | `lib/report_forge/reports.ex`, `test/report_forge/reports_test.exs` | Done | Completion writes storage outside the locked report transaction and compensates if finalization fails. |
| Paginated report listings are enforced | `openapi.yaml`, `lib/report_forge/reports.ex`, `test/report_forge_web/router_test.exs` | Done | List responses expose `meta.pagination` with bounded `limit` and opaque `next_cursor`. |
| Runtime hardening is production-shaped | `Dockerfile`, `docker-compose.yml`, `lib/report_forge/release.ex` | Done | Uses digest-pinned base images, a release-based non-root container, container healthcheck against readiness, read-only Compose runtime controls, and release migration command. |
| Tenant isolation is covered | `docs/security/authorization-matrix.md`, `test/report_forge_web/router_test.exs` | Done | Cross-tenant reads normalize to `404`. |
| Financial export threat model exists | `docs/security/threat-model.md` | Done | Signed URLs, retention, storage, tenant access, and abuse cases. |
| Observability evidence exists | `docs/architecture/observability.md`, `docs/architecture/grafana-dashboard.json`, `test/report_forge/otlp_export_test.exs` | Done | Trace propagation and OTLP export are tested. |
| Benchmark evidence exists | `benchmarks/baseline.md`, `benchmarks/results/2026-05-29/README.md` | Done | Includes smoke/load/stress/spike and resource notes. |
| Operational cost is documented | `docs/operational-cost.md` | Done | Includes infrastructure, debug, deployment, backup, monitoring, lock-in. |
| Spec-driven workflow is documented | `docs/spec-driven/implementation-plan.md`, `docs/spec-driven/verification-report.md` | Done | Verification report records commands and results. |
| 100% turnkey production claim is avoided | `docs/architecture/production-readiness-review.md` | Done | Remaining production gaps are explicit. |

## Out of Scope

- New report exporters.
- Kubernetes manifests, Helm charts, or autoscaling config.
- Data lake, CDC, or warehouse pipelines.
- Managed cloud provisioning.
- Secret-manager integration and key-versioned signing rotation.
- SLO alert routing against real production traffic.
