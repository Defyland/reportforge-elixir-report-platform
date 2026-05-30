# Use Cases

## Request A Cash Position Export

A tenant submits a `cash_position` report with filters and an idempotency key.
The API records a queued report, emits `report.requested`, and schedules durable
execution through Oban.

## Deduplicate A Retried Submission

A client retries the same report request after a timeout. ReportForge compares
the tenant, idempotency key, and fingerprint so the existing report is returned
instead of creating duplicate work.

## Track Report Progress

An operator reads the report event timeline to determine whether work is
queued, started, progressing through bounded stages, uploaded, completed,
failed, or cancelled.

## Download A Completed Artifact

A tenant requests a download URL for a completed report. ReportForge creates a
short-lived signed URL that resolves to the artifact only while metadata,
tenant scope, signature, and expiry remain valid.

## Retry Or Cancel Work

A tenant can cancel queued or running work, then retry terminal failed or
cancelled reports. Each transition is recorded through report events and audit
logs.

## Clean Up Expired Artifacts

Scheduled maintenance removes expired artifacts and terminal report records
according to tenant retention policy. The goal is to reduce financial data
exposure and keep storage cost bounded.
