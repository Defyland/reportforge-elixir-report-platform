# Financial Export Threat Model

This model focuses on generated financial exports, signed URLs, tenant access,
retention, and artifact storage. It complements the architecture-level threat
model in `docs/architecture/threat-model.md`.

## Assets

- Tenant API keys and hashed API-key secrets.
- Financial report definitions, filters, selected columns, and row counts.
- Generated CSV, JSON, and ZIP artifacts.
- Artifact metadata: storage key, checksum, byte size, content type, and expiry.
- Signed download URLs and signing secret material.
- Report lifecycle events and audit logs.
- Tenant retention policy.

## Trust Boundaries

- Public HTTP clients cross into the API through `ReportForgeWeb.Router`.
- Tenant authentication maps API keys to `organization_id`.
- Oban workers execute outside the original HTTP request context.
- Artifact storage can be local, database-backed, or S3-compatible object storage.
- Signed URLs convert authenticated API state into temporary download access.
- Cleanup jobs cross from retention policy into metadata and object deletion.

## Threats And Controls

| Threat | Scenario | Current control | Future hardening |
| --- | --- | --- | --- |
| Cross-tenant report access | Tenant A requests Tenant B report ID. | Every report, event, and API-key lookup is scoped by `organization_id`; cross-tenant reads normalize to `404`. | Add tenant-scoped authorization tests for every new endpoint. |
| Signed URL leakage | A URL is copied to an unintended recipient. | Signed URLs expire, tokens include report and organization context, and artifact metadata has `expires_at`. | Shorter TTL by sensitivity tier and emergency token invalidation. |
| Signing secret compromise | An attacker can mint valid download tokens. | Secret is configurable by env/file and downloads still resolve through artifact metadata. | Managed secret store, rotation window, and key versioning. |
| Long-lived financial exports | Sensitive files remain after business need expires. | Tenant retention policy, cleanup worker, expiry metadata, and cleanup runbooks. | Object lifecycle policy and retention/legal-hold workflow. |
| Object storage misconfiguration | Bucket becomes public or objects are overwritten. | MinIO/S3 adapter uses explicit bucket/key config; metadata remains tenant-scoped in PostgreSQL. | Bucket policy drift detection, encryption, versioning, and orphan-object reconciliation. |
| Replay or duplicate exports | Aggressive clients create many copies of the same report. | Idempotency keys, fingerprint dedupe, rate limiting, and unique database constraints. | Client-specific quotas and abuse dashboards. |
| Event data leakage | Lifecycle event payload includes financial rows or signed URLs. | Event docs prohibit row contents, credentials, API keys, and signed tokens. | Schema validation for event payload allowlists. |
| Worker memory pressure | Large report is loaded into memory before upload. | Stream-first design is documented as the next exporter constraint. | Implement bounded streaming exporters and memory benchmarks before larger templates. |
| Partial upload inconsistency | Object is written but metadata transaction fails, or vice versa. | Metadata includes checksum, storage key, byte size, expiry, and cleanup paths. | Reconciliation job for orphaned objects and failed metadata writes. |
| Unauthorized retry or cancellation | A tenant manipulates report state outside its scope. | Retry/cancel endpoints require tenant API key and report ownership. | Per-action roles if API keys become permissioned. |

## Retention Rules

- Report artifact metadata must carry an explicit expiration.
- Expired artifacts should be removed by scheduled cleanup.
- Retention should be tenant-scoped and auditable.
- Signed URLs must expire before or at artifact expiration.
- Retention failures are operational incidents when they affect financial data.

## Storage Rules

- PostgreSQL is the source of authorization and artifact metadata.
- Object storage is the source of artifact bytes.
- Storage keys are internal identifiers, not public URLs.
- Checksums are used to detect corruption and support auditability.
- Public bucket access is not required and should remain disabled.

## Residual Risks

- Secret manager integration is deployment-specific and remains future work.
- Cloud bucket encryption and lifecycle policies require the target provider.
- Kubernetes manifests are deferred until worker concurrency and resource limits
  are tuned.
- Data lake and CDC pipelines are out of scope; ReportForge produces operational
  exports, not analytical warehouse ingestion.
