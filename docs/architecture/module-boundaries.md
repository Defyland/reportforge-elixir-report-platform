# Module Boundaries

## HTTP Boundary

`ReportForgeWeb.Router` owns request parsing, authentication plugs, response
format, error envelopes, and operational endpoints. It should not contain report
generation logic or storage-specific code.

## Identity Boundary

`ReportForge.Identity` owns organizations and API keys. It hashes secrets,
revokes keys, and resolves tenant context. It should not decide report state.

## Reports Boundary

`ReportForge.Reports` owns report commands, lifecycle transitions,
idempotency, signed URL decisions, artifact metadata, and report events. It is
the main domain boundary for financial exports.

## Worker Boundary

`ReportForge.Reports.Worker` owns asynchronous execution orchestration. It
should call domain functions instead of updating database rows directly outside
approved lifecycle paths.

## Storage Boundary

`ReportForge.ArtifactStorage` is a behavior that keeps bytes outside the report
domain. Adapters can change without changing report authorization rules.

## Observability Boundary

`ReportForge.Telemetry`, `ReportForge.Metrics`, `ReportForge.Tracing`, and
`ReportForge.Observability` own operational signals. They should describe what
happened without owning business decisions.

## Maintenance Boundary

Maintenance workers own cleanup and retention execution. They should be safe to
rerun and should preserve tenant and audit semantics.
