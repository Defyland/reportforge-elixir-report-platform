# Database Design

The current application flow is PostgreSQL-backed in the main runtime path:

- [lib/report_forge/repo.ex](../../lib/report_forge/repo.ex)
- [lib/report_forge/identity.ex](../../lib/report_forge/identity.ex)
- [lib/report_forge/reports.ex](../../lib/report_forge/reports.ex)
- [priv/repo/migrations](../../priv/repo/migrations/)
- [test/report_forge/persistence_test.exs](../../test/report_forge/persistence_test.exs)

That means the durable model is not only planned; it is already executable in the API flow and covered by both request tests and dedicated database tests.

## Core tables

- `organizations`
- `api_keys`
- `reports`
- `report_events`
- `report_artifacts`
- `audit_logs`
- `oban_jobs`
- `oban_peers`

## Constraints and indexes

- unique `organizations.slug`
- unique `api_keys.key_prefix`
- unique `(organization_id, idempotency_key)` where `idempotency_key` is not null
- index `(organization_id, fingerprint)` for deduplication lookups
- index `(organization_id, status, inserted_at)` for report listing
- index `(status, completed_at, failed_at, cancelled_at)` for retention cleanup
- index `(report_id, inserted_at)` for event history playback
- indexes `(organization_id, inserted_at)` and `(action, inserted_at)` for audit queries

## Transaction boundaries

- organization creation plus bootstrap API key issuance should be atomic
- audit-log creation should never partially corrupt the primary business transaction
- report acceptance and initial event creation should be atomic
- report completion plus artifact metadata update should be atomic
- cleanup jobs should either delete matching rows fully or leave them untouched

## Migration strategy

- keep public API contracts stable while extending the schema
- keep Oban job payloads backward compatible while queue behavior evolves
- backfill or migrate artifact references before moving from local object storage to a remote object backend
- keep cleanup and audit indexes aligned with retention and forensics use cases

## Rollback strategy

- maintain dual-write compatibility only during the cutover window
- keep signed download verification independent of storage backend
- keep queue names and worker args stable during queue evolution
- rely on cascading foreign keys when retention deletes terminal reports
