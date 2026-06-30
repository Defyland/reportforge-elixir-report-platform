# ADR 0007: Publish the Repository Under the MIT License

## Status

Accepted.

## Context

ReportForge is already a public report-platform asset with async lifecycle
evidence, signed artifact handling, and runbook guidance. Without an explicit
license, the repository can be reviewed but its reuse boundary remains legally
ambiguous.

## Decision

Publish the repository under the MIT License and document that clearly in the
README.

## Consequences

Positive:

- Teams can study and adapt the report-lifecycle patterns with a permissive
  license.
- The public portfolio signal matches the repo's existing documentation depth.

Negative:

- Downstream forks may copy only the app surface and skip the runbook caveats.
- Third-party asset and dependency licenses still require separate review.
