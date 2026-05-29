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
  ".github/workflows/ci.yml"
  "benchmarks/baseline.md"
  "benchmarks/results/README.md"
  "docs/implementation-plan.md"
  "docs/engineering-baseline.md"
  "docs/api/error-format.md"
  "docs/api/http-examples.md"
  "docs/api/authorization-matrix.md"
  "docs/architecture/overview.md"
  "docs/architecture/domain-model.md"
  "docs/architecture/database-design.md"
  "docs/architecture/observability.md"
  "docs/architecture/threat-model.md"
  "docs/architecture/grafana-dashboard.json"
  "docs/runbooks/common-issues.md"
)

required_dirs=(
  "docs/adr"
  "docs/api"
  "docs/architecture"
  "docs/benchmarks"
  "docs/diagrams"
  "docs/runbooks"
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
