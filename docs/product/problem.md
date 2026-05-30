# Product Problem

ReportForge addresses the operational gap between transactional finance systems
and long-running financial exports. Finance teams need cash-position snapshots,
ledger summaries, and invoice audits, but those exports are often too large or
too slow to run inline inside the core application.

The product problem is not only file generation. The harder problem is making
large exports safe, observable, repeatable, and tenant-isolated while preserving
the transactional system that owns the source of truth.

## User Pain

- Inline exports tie user-facing request latency to slow queries and file IO.
- Ad-hoc batch scripts produce weak audit trails and inconsistent retries.
- Duplicate export requests waste compute and create reconciliation confusion.
- Operators cannot explain whether a report is queued, running, uploaded,
  completed, failed, or cancelled.
- Financial artifacts can outlive their business need if retention is not
  explicit.

## Product Outcome

ReportForge turns exports into explicit report jobs with lifecycle state,
idempotency, signed access, audit logs, retention, and operational evidence.
The result is a backend service that can be discussed as a production-shaped
platform component instead of a one-off export endpoint.
