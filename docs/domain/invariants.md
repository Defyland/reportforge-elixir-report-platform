# Domain Invariants

## Tenant Isolation

- Authenticated API calls resolve one `organization_id` from one API key.
- Report reads, events, retries, cancellations, downloads, and artifact access
  are scoped by `organization_id`.
- Cross-tenant report access is normalized to `404` to avoid leaking existence.

## Idempotency And Deduplication

- `idempotency_key` is unique per tenant when provided.
- Fingerprint-based lookup allows equivalent retried payloads to return an
  existing report.
- The database remains the concurrency control boundary for duplicate writes.

## Report Lifecycle

- A report starts as `queued`.
- Worker execution moves it to `running`.
- Successful storage and metadata persistence move it to `succeeded`.
- Exhausted or definitive failures move it to `failed`.
- User or operator cancellation moves it to `cancelled`.
- Terminal states are not mutated except through explicit retry behavior.

## Artifact Access

- Artifact bytes are only useful when metadata authorizes access.
- Signed URLs are temporary and must not appear in lifecycle event payloads.
- Checksum, byte size, content type, and storage key are durable metadata.
- Expired artifacts are cleanup candidates.

## Retention

- Tenant retention controls terminal report and artifact cleanup.
- Cleanup must be auditable and safe to rerun.
- Retention failures affecting financial exports are operational incidents.
