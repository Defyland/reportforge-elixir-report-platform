# Scalability

## Hot Paths

- `POST /api/v1/reports`: validates input, authenticates the tenant, checks
  idempotency, persists report state, emits `report.requested`, and enqueues
  Oban work.
- `GET /api/v1/reports/{id}` and `GET /api/v1/reports/{id}/events`: serve
  polling clients and operators.
- `GET /downloads/{token}`: verifies signed access and streams or redirects
  artifact bytes.
- Oban worker execution: generates artifacts, writes storage bytes, and
  completes report metadata.

## Read-Heavy Operations

Report status polling, lifecycle event reads, download URL requests, health,
readiness, and metrics are read-heavy. These paths need tenant-scoped indexes
and predictable payload sizes before they need caching.

## Write-Heavy Operations

Report creation, lifecycle event insertion, audit logging, artifact metadata
updates, and Oban jobs are write-heavy. The database is the coordination point
for correctness and should be monitored for lock contention and queue buildup.

## Fastest Growing Tables

- `report_events`: grows with each lifecycle transition and retry.
- `report_artifacts`: grows with completed reports until cleanup.
- `reports`: grows with report requests and retention policy.
- `audit_logs`: grows with key management, downloads, retry, and cancellation.
- `oban_jobs`: grows under worker backlog or retry storms.

## Queue Buildup Risks

Large reports can exhaust worker capacity if queue concurrency is not tuned.
`source_timeout`-style failures should retry with backoff, while validation
failures should fail definitively. Queue depth and retry exhaustion should be
alerted before users experience long delays.

## Hot Tenant Keys

`organization_id` is the main partitioning and authorization key. A single
large tenant can become hot through frequent polling, duplicate report
submissions, or large artifact downloads. Tenant-level rate limits and future
quotas are the first mitigation before physical sharding.

## Horizontal Scaling

The API can scale horizontally behind a load balancer because request state is
stored in PostgreSQL and artifacts are externalized. Workers should scale as a
separate pool so report generation does not starve HTTP traffic.

## Storage Scaling

Artifact bytes should stay outside PostgreSQL. Local storage is suitable for
tests and development. MinIO/S3-compatible storage is the production-shaped
path, with provider lifecycle policies, encryption, and orphan reconciliation
added per environment.

## Consistency Boundaries

Strong consistency is required for tenant authorization, API-key lookup,
idempotency, report state transitions, artifact metadata, and signed URL
authorization. Eventual consistency is acceptable for dashboards, aggregate
metrics, exported traces, and future notifications.

## Deferred Scaling Work

Kubernetes, data lake, CDC, sharding, read replicas, and cache layers are
deferred until there is measured pressure. Adding those too early would obscure
the current correctness and operability story.
