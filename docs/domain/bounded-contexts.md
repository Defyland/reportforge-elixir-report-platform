# Bounded Contexts

## Identity

Owns organizations, API keys, credential hashing, revocation, and tenant lookup.
It does not own report lifecycle or artifact access.

Primary modules:

- `ReportForge.Identity`
- `ReportForge.Identity.Organization`
- `ReportForge.Identity.ApiKey`

## Reporting

Owns report creation, idempotency, lifecycle state, report events, retry,
cancellation, artifact metadata, and signed download decisions.

Primary modules:

- `ReportForge.Reports`
- `ReportForge.Reports.Report`
- `ReportForge.Reports.ReportEvent`
- `ReportForge.Reports.Artifact`
- `ReportForge.Reports.Worker`

## Artifact Storage

Owns artifact bytes behind a behavior so the database does not become the
binary store. PostgreSQL remains the authorization and metadata source of truth.

Primary modules:

- `ReportForge.ArtifactStorage`
- `ReportForge.ArtifactStorage.Local`
- `ReportForge.ArtifactStorage.S3`

## Maintenance

Owns scheduled cleanup of expired artifacts and tenant retention windows. It
does not decide report business state.

Primary modules:

- `ReportForge.Maintenance.ArtifactCleanupWorker`
- `ReportForge.Maintenance.ReportRetentionWorker`

## Observability And Audit

Owns logs, metrics, traces, persistent audit records, and operational signals.
It records facts about sensitive activity without becoming the primary domain
owner.

Primary modules:

- `ReportForge.Audit`
- `ReportForge.Metrics`
- `ReportForge.Observability`
- `ReportForge.Telemetry`
- `ReportForge.Tracing`
