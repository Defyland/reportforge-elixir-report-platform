# Domain Model

## Organization

- primary tenant boundary
- owns retention policy
- owns API keys
- owns all reports and report events

## ApiKey

- belongs to exactly one organization
- stores only hashed secret material
- can be revoked without deleting history
- last-used timestamps support operational review

## Report

- aggregate root for each asynchronous export request
- state machine: `queued -> running -> succeeded|failed|cancelled`
- tracks template, format, filters, progress, artifact metadata, and terminal errors
- deduplicated by explicit idempotency key or inferred fingerprint

## ReportEvent

- immutable lifecycle evidence
- ordered per report
- captures state, progress, correlation ID, and event metadata

## Artifact

- binary output for CSV, JSON, or ZIP
- referenced through a signed URL
- stored through the active `ReportForge.ArtifactStorage` adapter
- keeps authorization, checksum, content type, byte size, storage key, and TTL metadata in PostgreSQL
