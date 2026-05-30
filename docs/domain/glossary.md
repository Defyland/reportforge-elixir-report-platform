# Domain Glossary

| Term | Meaning |
| --- | --- |
| Organization | Tenant boundary that owns API keys, reports, events, artifacts, audit logs, and retention policy. |
| API key | Tenant credential presented through `x-api-key`; only the digest is stored. |
| Report | Async export request with template, format, filters, status, fingerprint, and lifecycle timestamps. |
| Report event | Immutable lifecycle fact such as `report.requested`, `report.started`, or `report.completed`. |
| Artifact | Generated file metadata in PostgreSQL plus bytes in the active storage adapter. |
| Artifact storage | Boundary implemented by `ReportForge.ArtifactStorage` for local or S3-compatible bytes. |
| Idempotency key | Client-supplied key that prevents duplicate work for retried report creation. |
| Fingerprint | Server-computed request digest used to detect equivalent report submissions. |
| Signed URL | Short-lived download URL generated from report, organization, artifact, and expiry state. |
| Retention | Tenant-scoped policy controlling artifact and terminal-report cleanup. |
| Correlation ID | Request-to-worker identifier for debugging related logs, traces, and events. |
| Trace ID | OpenTelemetry identifier propagated from HTTP request into async report execution. |
