# ADR 0002: Deduplication and Signed Downloads

## Status

Accepted

## Context

Reporting platforms are prone to duplicate submissions from retries, impatient operators, and scheduler overlap. They also need artifact delivery without broad unauthenticated access.

## Decision

- use idempotency keys when callers provide them
- also compute a tenant-scoped fingerprint from template, format, and filters
- expose artifact downloads through signed URLs with expiry

## Consequences

- repeated create calls can return an existing report without starting new work
- tenants cannot use another tenant's signed artifact reference
- the current slice stores artifact payloads in PostgreSQL, so signed URLs remain valid across process restarts while the row exists
