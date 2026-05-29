# Senior Technical Assessment

This note evaluates whether the current `reportforge-elixir-report-platform` implementation demonstrates senior-level engineering judgment, and records the gaps that were tightened after the review.

## Verdict

The repository already shows strong senior signals. The author made defensible trade-offs, kept the product narrative coherent, and translated the spec into a working vertical slice instead of stopping at scaffolding.

The strongest evidence is not one isolated feature, but the combination of:

- contract-first API design with [openapi.yaml](../../openapi.yaml)
- transactional persistence and invariants in PostgreSQL-backed flows
- durable async execution with Oban instead of a fragile in-memory worker path
- operational concerns such as audit logs, traces, metrics, cleanup, and runbooks
- tests across request, database, async, concurrency, failure, and repository-spec compliance layers

## What already validates the author positively

### Architecture and trade-offs

- The code does not pretend to be production-complete infrastructure, but it does make that boundary explicit.
- Choosing Plug + Bandit for the first slice was a good scope-control decision, not a shortcut disguised as architecture.
- Moving from ephemeral execution to PostgreSQL + Oban shows the right instinct: durability before ornamental complexity.

### Data consistency

- Report creation, lifecycle transitions, artifact persistence, and audit writes are modeled with transaction boundaries instead of best-effort chaining.
- Idempotency and fingerprint deduplication are implemented as domain behavior, not just documented intentions.
- Concurrent idempotency and fingerprint tests now prove the database constraints under race, not only the happy sequential path.
- The schema and persistence tests prove that the author understands uniqueness, foreign keys, and rollback behavior.

### Operational maturity

- The project includes observability, security, and runbook material early instead of deferring it to “later”.
- Trace correlation is propagated across HTTP and async boundaries, which is a strong signal of systems thinking.
- The benchmark folder contains real captured evidence, not placeholder prose.

### Delivery discipline

- The repository history uses atomic Conventional Commits.
- The work is spec-driven and leaves reviewable artifacts in docs, tests, and CI.

## What needed to be better technically

These were not cosmetic issues. They were the main places where the implementation still needed tightening to match a higher operational bar.

### Readiness was too static

`GET /readyz` previously returned a hardcoded healthy payload. That is acceptable for a sketch, but not for a serious service slice. A readiness endpoint should validate the runtime dependencies that make the service actually ready to receive traffic.

### Artifact downloads did not preserve the artifact media type explicitly

The signed download flow worked, but the HTTP response path did not set the artifact `content-type` explicitly. That weakens correctness for clients and leaves too much behavior to defaults.

### Repository-level compliance was not sufficiently executable

The repository had strong docs and a shell validator, but more of the spec contract needed to live inside ExUnit so regressions would fail in the main test suite instead of only during manual review.

### Artifact persistence was too coupled to the report context

The first implementation persisted artifacts directly from `ReportForge.Reports`. That worked, but it made a future move to S3, MinIO, or another object backend more invasive than necessary. A senior slice should keep database metadata transactional while moving artifact bytes behind a storage boundary.

### Async failures needed classified retry behavior

The worker could mark a report failed, but transient errors such as upstream timeouts and temporary storage unavailability were treated like terminal failures. That is not the behavior expected from a durable background execution system.

## What was changed in this review pass

- added [test/report_forge/spec_compliance_test.exs](../../test/report_forge/spec_compliance_test.exs) to codify repository-level spec expectations in ExUnit
- added [lib/report_forge/readiness.ex](../../lib/report_forge/readiness.ex) so readiness now checks database reachability, Oban availability, and signing-secret presence
- updated [lib/report_forge_web/router.ex](../../lib/report_forge_web/router.ex) so `/readyz` returns `503` when dependencies are not ready
- hardened signed artifact responses in [lib/report_forge_web/router.ex](../../lib/report_forge_web/router.ex) to return the stored artifact media type and `X-Content-Type-Options: nosniff`
- added [lib/report_forge/artifact_storage.ex](../../lib/report_forge/artifact_storage.ex), [lib/report_forge/artifact_storage/local.ex](../../lib/report_forge/artifact_storage/local.ex), and the compatibility PostgreSQL adapter in [lib/report_forge/artifact_storage/database.ex](../../lib/report_forge/artifact_storage/database.ex)
- added [lib/report_forge/artifact_storage/s3.ex](../../lib/report_forge/artifact_storage/s3.ex) with AWS Signature Version 4, S3/MinIO runtime configuration, presigned redirects, and compensation for metadata insert failures
- moved artifact bytes out of PostgreSQL for the default runtime while keeping metadata, checksum, content type, storage key, and expiry in the database
- moved report retry cleanup, download lookup, completion persistence, and maintenance expiry through the storage boundary
- added concurrent idempotency and fingerprint tests in [test/report_forge/reports_test.exs](../../test/report_forge/reports_test.exs)
- classified retryable report worker failures with Oban `max_attempts: 3`, deterministic backoff, and `report.retry_scheduled` lifecycle events
- added response contract tests in [test/report_forge_web/openapi_contract_test.exs](../../test/report_forge_web/openapi_contract_test.exs), validating live JSON responses against `openapi.yaml`
- added `:telemetry` events for HTTP requests, report lifecycle metrics, retries, and cleanup while preserving Prometheus output
- added [test/report_forge/artifact_storage_test.exs](../../test/report_forge/artifact_storage_test.exs) and worker retry tests to prove the new contracts
- added [test/report_forge/artifact_storage_s3_test.exs](../../test/report_forge/artifact_storage_s3_test.exs) to prove S3 request signing, transient failure classification, redirect generation, and object-delete compensation
- extended [test/report_forge_web/router_test.exs](../../test/report_forge_web/router_test.exs) to prove the degraded-readiness path and the hardened download headers
- updated [docs/architecture/observability.md](./observability.md), [docs/runbooks/common-issues.md](../runbooks/common-issues.md), and [openapi.yaml](../../openapi.yaml) to reflect the stricter runtime behavior

## Final calibration

If this repository were presented as a portfolio project, I would evaluate it as credible senior-level work with one caveat: the value comes from the engineering judgment, not just the feature list.

The review changes above sharpen that judgment in the places where senior code is usually exposed under pressure:

- probes must prove something real
- HTTP responses must preserve contract semantics precisely
- repository standards should be executable, not only described
- durable workers should distinguish retryable operational failures from terminal domain failures
- replaceable infrastructure boundaries should exist before the implementation is forced to migrate
