# Implementation Plan

## Scope

Apply the shared senior documentation and spec-driven standards to ReportForge
without broad refactors. The work is limited to `reportforge-elixir-report-platform/`
except reading shared specs from the repository root.

## Files to Create or Update

- `docs/spec-driven/senior-readiness-spec.md`
- `docs/spec-driven/implementation-plan.md`
- `docs/spec-driven/verification-report.md`
- `docs/engineering-case-study.md`
- `docs/product/*.md`
- `docs/domain/*.md`
- `docs/architecture/c4-context.md`
- `docs/architecture/c4-container.md`
- `docs/architecture/deployment-view.md`
- `docs/architecture/module-boundaries.md`
- `docs/architecture/sequence-diagrams.md`
- `docs/security/authorization-matrix.md`
- `docs/security/data-classification.md`
- `docs/security/secrets.md`
- `docs/security/abuse-cases.md`
- `docs/scalability.md`
- `docs/operational-cost.md`
- `README.md`
- `scripts/validate_requirements.sh`
- `test/report_forge/spec_compliance_test.exs`
- `lib/report_forge/reports/worker.ex`
- `lib/report_forge/reports.ex`
- `test/report_forge/reports/worker_test.exs`
- `docs/diagrams/report-lifecycle-sequence.md`

## Acceptance Criteria Mapping

| Acceptance criterion | Planned change |
| --- | --- |
| Spec-driven files exist | Add the three required docs under `docs/spec-driven/`. |
| Product evidence exists | Add product problem, personas, use cases, non-goals, roadmap, and pricing/plans docs. |
| Domain evidence exists | Add glossary, bounded contexts, aggregates, invariants, and state machine docs. |
| Architecture evidence exists | Add C4-style docs, module boundaries, sequence index, and deployment view. |
| Security evidence exists | Add security authorization matrix, data classification, secrets, and abuse cases docs. |
| Scalability/cost evidence exists | Add `docs/scalability.md` and `docs/operational-cost.md`. |
| README points to evidence | Add references to case study, spec-driven docs, product/domain docs, scale, and cost. |
| Documentation matches code | Rename worker lifecycle events to canonical `report.progress_updated` and `report.uploaded`. |
| Baseline enforces evidence | Update shell baseline and ExUnit compliance test. |
| Verification is reproducible | Record command results in `verification-report.md`. |

## Verification Commands

- `mix format --check-formatted`
- `mix test test/report_forge/reports/worker_test.exs`
- `mix test test/report_forge/spec_compliance_test.exs`
- `bash scripts/validate_requirements.sh`
- `python3 -m json.tool docs/events/report_lifecycle_event.v1.json`
- `python3 -m json.tool docs/events/report_progress_updated.v1.json`
- `npx markdownlint-cli2 README.md "docs/**/*.md" "benchmarks/**/*.md"`
- `git diff --check`
- `npx @redocly/cli@latest lint openapi.yaml`
- `mix ci`

## Risks

- Documentation can overclaim production readiness. Mitigation: mark managed
  infra, secret rotation, and real SLO alerting as deferred.
- Event renaming can break tests. Mitigation: update worker tests and lifecycle
  sequence docs together.
- New docs can become stale. Mitigation: include them in baseline validation and
  spec compliance tests.

## Deferred Work

- New exporters.
- Kubernetes, Helm, or Terraform.
- Data lake or CDC.
- Managed cloud secret store.
- Alert routing validated with real production traffic.
