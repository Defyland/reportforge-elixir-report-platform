#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"

if [[ "$SCRIPT_DIR" == "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="."
fi

ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

required_paths=(
  "README.md"
  "openapi.yaml"
  "mix.exs"
  "Dockerfile"
  ".github/workflows/ci.yml"
  "config/prod.exs"
  "docker-compose.yml"
  "benchmarks/baseline.md"
  "benchmarks/results/README.md"
  "docs/implementation-plan.md"
  "docs/engineering-baseline.md"
  "docs/engineering-case-study.md"
  "docs/spec-driven/senior-readiness-spec.md"
  "docs/spec-driven/implementation-plan.md"
  "docs/spec-driven/verification-report.md"
  "docs/product/problem.md"
  "docs/product/personas.md"
  "docs/product/use-cases.md"
  "docs/product/non-goals.md"
  "docs/product/roadmap.md"
  "docs/product/pricing-or-plans.md"
  "docs/domain/glossary.md"
  "docs/domain/bounded-contexts.md"
  "docs/domain/aggregates.md"
  "docs/domain/invariants.md"
  "docs/domain/state-machines.md"
  "docs/api/error-format.md"
  "docs/api/http-examples.md"
  "docs/api/authorization-matrix.md"
  "docs/architecture/overview.md"
  "docs/architecture/c4-context.md"
  "docs/architecture/c4-container.md"
  "docs/architecture/domain-model.md"
  "docs/architecture/database-design.md"
  "docs/architecture/deployment-readiness.md"
  "docs/architecture/module-boundaries.md"
  "docs/architecture/sequence-diagrams.md"
  "docs/architecture/deployment-view.md"
  "docs/architecture/large-report-pipeline.md"
  "docs/architecture/observability.md"
  "docs/architecture/threat-model.md"
  "docs/architecture/grafana-dashboard.json"
  "docs/architecture/production-readiness-review.md"
  "docs/adr/0006-stream-first-before-platform-complexity.md"
  "docs/events/README.md"
  "docs/security/threat-model.md"
  "docs/security/authorization-matrix.md"
  "docs/security/data-classification.md"
  "docs/security/secrets.md"
  "docs/security/abuse-cases.md"
  "docs/scalability.md"
  "docs/operational-cost.md"
  "docs/runbooks/common-issues.md"
  "docs/runbooks/failure-drills.md"
  "docs/runbooks/report-artifact-exposure.md"
  "ops/grafana/provisioning/dashboards/reportforge.yml"
  "ops/grafana/provisioning/datasources/prometheus.yml"
  "ops/otel/collector.yml"
  "ops/prometheus/alerts.yml"
  "ops/prometheus/prometheus.yml"
  "scripts/smoke.sh"
)

required_dirs=(
  "docs/adr"
  "docs/api"
  "docs/architecture"
  "docs/benchmarks"
  "docs/diagrams"
  "docs/domain"
  "docs/events"
  "docs/product"
  "docs/runbooks"
  "docs/security"
  "docs/spec-driven"
  "benchmarks/results"
)

required_readme_headings=(
  "## What is this product?"
  "## Problem it solves"
  "## Target users"
  "## Main features"
  "## Architecture overview"
  "## Tech stack"
  "## Domain model"
  "## API documentation"
  "## Async or event architecture"
  "## Database design"
  "## Testing strategy"
  "## Performance benchmarks"
  "## Observability"
  "## Security considerations"
  "## Trade-offs and decisions"
  "## How to run locally"
  "## How to run tests"
  "## Failure scenarios"
  "## Roadmap"
)

for path in "${required_paths[@]}"; do
  [[ -f "$path" ]] || { echo "Missing required file: $path" >&2; exit 1; }
done

for path in "${required_dirs[@]}"; do
  [[ -d "$path" ]] || { echo "Missing required directory: $path" >&2; exit 1; }
done

for heading in "${required_readme_headings[@]}"; do
  grep -Fq "$heading" README.md || { echo "Missing README heading: $heading" >&2; exit 1; }
done

echo "Repository baseline structure validated."
