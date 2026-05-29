# ADR 0006: Prioritize Stream-First Reports Before Platform Complexity

## Status

Accepted.

## Context

ReportForge exists to generate large financial reports without blocking the API
or overloading transactional systems. The core risk is not whether the service
can be deployed to a cluster; the core risk is whether report execution can stay
bounded, observable, retryable, tenant-safe, and storage-safe as artifact sizes
grow.

Kubernetes, a data lake, CDC, or lakehouse layers would add platform surface area
before the export pipeline proves its memory, storage, retry, and lifecycle
semantics. They also risk shifting the project narrative from operational report
delivery to analytics infrastructure.

## Decision

Prioritize stream-first report delivery before platform complexity.

The next implementation focus remains:

- stream-first generation for large CSV, JSON, and ZIP artifacts
- bounded memory and chunk-oriented progress reporting
- object-storage boundaries with checksum, byte size, content type, and expiry
- retry safety for transient source or storage failures
- lifecycle events for requested, started, progress, uploaded, completed, failed,
  and cancelled states

Kubernetes manifests, Helm charts, CDC, and lakehouse-style raw/bronze/silver/gold
layers are deferred until the report execution model is proven under load.

No new exporters are introduced by this ADR.

## Consequences

- The product narrative stays centered on reliable report generation.
- Deployment can remain Docker Compose and CI oriented while the worker model matures.
- Future platform work can reuse the documented report lifecycle events.
- Infrastructure choices remain portable until runtime constraints are measured.
- The project avoids premature distributed-system complexity.
- Future Kubernetes work should start from measured CPU, memory, queue, and
  storage behavior rather than guesses.
- Future data-lake work should consume completed artifacts or dedicated export
  feeds only after ReportForge's operational export contract is stable.
