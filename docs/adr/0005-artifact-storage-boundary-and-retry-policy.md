# ADR 0005: Artifact Storage Boundary and Retry Policy

## Status

Accepted

## Context

ReportForge initially stored generated artifacts directly through the reports context. That kept the first durable slice small, but it coupled report lifecycle code to the persistence backend and made a future object-storage move too invasive.

The worker also treated transient operational failures and terminal domain failures the same way. For a background export platform, temporary upstream timeouts or storage unavailability should be retried with predictable backoff before the report is marked failed.

## Decision

Introduce `ReportForge.ArtifactStorage` as the boundary for artifact writes, reads, deletion, and expiry cleanup.

Keep `ReportForge.ArtifactStorage.Database` as the current adapter so the shipped runtime remains PostgreSQL-only, while making future S3, MinIO, or managed object-storage adapters localized changes.

Configure report workers with three Oban attempts and deterministic quadratic backoff. Retry only classified transient errors:

- `source_timeout`
- `storage_unavailable`
- `unexpected_error`

When a retryable error occurs before the final attempt, move the report back to `queued`, preserve the last error for operator visibility, increment the attempt counter, and persist a `report.retry_scheduled` event. On the final attempt, mark the report `failed`.

## Consequences

- Report lifecycle code no longer owns artifact persistence details.
- Cleanup and download flows use the same storage contract as report completion.
- Transient failures are visible in report history instead of being silent Oban internals.
- The current implementation still avoids adding MinIO/S3 operational overhead to the local slice.
- Future object-storage migration requires a new adapter and targeted tests, not a rewrite of report lifecycle logic.
