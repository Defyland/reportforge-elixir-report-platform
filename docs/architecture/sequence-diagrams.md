# Sequence Diagrams

This page is the navigation point for ReportForge sequence evidence.

## Report Lifecycle

The canonical report lifecycle sequence is documented in
[docs/diagrams/report-lifecycle-sequence.md](../diagrams/report-lifecycle-sequence.md).
It covers request acceptance, Oban execution, progress events, upload, metadata
completion, and signed download access.

## System Context

The high-level context diagram is documented in
[docs/diagrams/system-context.md](../diagrams/system-context.md). It shows the
API, PostgreSQL, Oban, artifact storage, and observability dependencies.

## Sequence Rules

- Long-running generation must leave the HTTP request path.
- Report creation and `report.requested` event persistence must be atomic.
- Worker-side events should use canonical lifecycle names from
  [docs/events/README.md](../events/README.md).
- Artifact bytes are written through `ReportForge.ArtifactStorage`.
- Signed URLs are generated after a report succeeds and are not lifecycle event
  payloads.
