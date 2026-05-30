# Engineering Case Study

## 1. Product Context

ReportForge is a backend service for finance and operations teams that need
large financial exports without blocking transactional systems. It turns report
generation into an explicit async workflow with idempotency, signed downloads,
audit logs, retention, and operational evidence.

## 2. Domain Model

The core domain nouns are `Organization`, `ApiKey`, `Report`, `ReportEvent`,
and `Artifact`. `Organization` is the tenant boundary. `Report` owns lifecycle
state. `ReportEvent` records immutable timeline facts. `Artifact` stores
download metadata while bytes live behind the storage adapter.

## 3. Architecture

The service is a modular Elixir API using Plug, Bandit, Ecto, PostgreSQL, Oban,
and an artifact-storage behavior. The architecture is intentionally smaller
than Phoenix, but still production-shaped: HTTP edge, domain contexts, durable
jobs, database constraints, storage boundary, telemetry, metrics, and runbooks.

## 4. Key Trade-Offs

Plug and Bandit keep the executable slice focused, while Phoenix remains a
reasonable later option if the API grows. PostgreSQL is used for state and
coordination because idempotency, job execution, and event history need durable
consistency. Artifact bytes are stored outside PostgreSQL to avoid turning the
database into a file store.

## 5. Data Model

PostgreSQL stores organizations, API keys, reports, report events, artifact
metadata, audit logs, and Oban jobs. Constraints protect tenant slug uniqueness,
API-key prefix uniqueness, tenant-scoped idempotency, and event/report
relationships.

## 6. Consistency Model

Report acceptance and `report.requested` persistence are atomic. Idempotency is
enforced through database uniqueness and fingerprint lookup. Report completion
persists terminal metadata and lifecycle events through the Reports context.
Cross-tenant reads are rejected through tenant-scoped queries.

## 7. Failure Scenarios

The project models duplicate requests, source timeouts, storage write failures,
expired signed URLs, cross-tenant reads, rate limits, cancellation, retry, and
cleanup. Runbooks describe likely operator actions.

## 8. Performance Strategy

Long-running generation leaves the HTTP path and runs through Oban. Benchmarks
cover smoke, load, stress, and spike scenarios. The next performance boundary is
stream-first exporter implementation before adding larger templates.

## 9. Scalability Strategy

The API and workers can scale separately. Hot paths are report creation,
lifecycle polling, event history reads, and artifact downloads. PostgreSQL and
object storage are the main capacity dependencies. Queue concurrency should be
tuned per deployment.

## 10. Security Model

Tenant API keys scope authenticated endpoints. Signed URLs are short-lived
bearer capabilities. Financial artifacts are restricted data. Audit logs record
key management, downloads, retry, and cancellation. Threat models cover signed
URLs, tenant access, retention, and storage.

## 11. Observability

ReportForge emits request IDs, correlation IDs, traces, structured logs,
telemetry events, Prometheus metrics, health checks, readiness checks, report
events, and audit logs. The Compose stack includes an OpenTelemetry Collector,
Prometheus, and Grafana.

## 12. Operational Cost

The largest cost drivers are PostgreSQL, artifact storage, worker concurrency,
observability retention, and operational debugging. The repository documents
cost trade-offs without pretending to provision a full managed environment.

## 13. Maintainability

Module boundaries separate identity, reporting, storage, maintenance,
observability, and HTTP concerns. ADRs capture architecture trade-offs. Baseline
scripts and spec compliance tests prevent documentation evidence from silently
disappearing.

## 14. Product Decisions

The current product avoids dashboards, new exporters, data lake integration,
and Kubernetes manifests. That restraint keeps the senior signal focused on
correctness, safety, and operability rather than breadth.

## 15. What I Would Do Next

The next production step is implementing bounded stream-first exporters,
storage reconciliation, target-cloud secret rotation, deployment-specific SLO
alerts, and real infrastructure load testing.
