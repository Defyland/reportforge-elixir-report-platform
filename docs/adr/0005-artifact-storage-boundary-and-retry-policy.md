# ADR 0005: Artifact Storage Boundary and Retry Policy

## Status

Accepted

## Context

ReportForge initially stored generated artifacts directly through the reports context and PostgreSQL row body. That kept the first durable slice small, but it coupled report lifecycle code to the persistence backend and put large artifact bytes on the primary database path.

The worker also treated transient operational failures and terminal domain failures the same way. For a background export platform, temporary upstream timeouts or storage unavailability should be retried with predictable backoff before the report is marked failed.

## Decision

Introduce `ReportForge.ArtifactStorage` as the boundary for artifact writes, reads, streaming access, deletion, and expiry cleanup.

Use `ReportForge.ArtifactStorage.Local` as the default adapter. PostgreSQL stores artifact metadata such as token, filename, content type, checksum, byte size, storage key, and expiry; artifact bytes are written to local object storage on disk. Keep `ReportForge.ArtifactStorage.Database` as a compatibility adapter for legacy or test scenarios.

Downloads resolve signed metadata through PostgreSQL and stream the artifact from the storage adapter. Future S3, MinIO, or managed object-storage adapters should implement the same behaviour.

Configure report workers with three Oban attempts and deterministic quadratic backoff. Retry only classified transient errors:

- `source_timeout`
- `storage_unavailable`
- `unexpected_error`

When a retryable error occurs before the final attempt, move the report back to `queued`, preserve the last error for operator visibility, increment the attempt counter, and persist a `report.retry_scheduled` event. On the final attempt, mark the report `failed`.

## Consequences

- Report lifecycle code no longer owns artifact persistence details.
- Cleanup and download flows use the same storage contract as report completion.
- Artifact bytes no longer live in PostgreSQL for the default runtime.
- Transient failures are visible in report history instead of being silent Oban internals.
- The current implementation still avoids adding MinIO/S3 operational overhead to the local slice.
- Future object-storage migration requires a new adapter and targeted tests, not a rewrite of report lifecycle logic.
