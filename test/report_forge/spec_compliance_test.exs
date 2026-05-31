defmodule ReportForge.SpecComplianceTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  @required_files [
    "README.md",
    "openapi.yaml",
    ".github/workflows/ci.yml",
    "benchmarks/baseline.md",
    "docs/engineering-case-study.md",
    "docs/spec-driven/senior-readiness-spec.md",
    "docs/spec-driven/implementation-plan.md",
    "docs/spec-driven/verification-report.md",
    "docs/product/problem.md",
    "docs/product/personas.md",
    "docs/product/use-cases.md",
    "docs/product/non-goals.md",
    "docs/product/roadmap.md",
    "docs/product/pricing-or-plans.md",
    "docs/domain/glossary.md",
    "docs/domain/bounded-contexts.md",
    "docs/domain/aggregates.md",
    "docs/domain/invariants.md",
    "docs/domain/state-machines.md",
    "docs/api/error-format.md",
    "docs/api/http-examples.md",
    "docs/api/authorization-matrix.md",
    "docs/architecture/c4-context.md",
    "docs/architecture/c4-container.md",
    "docs/architecture/module-boundaries.md",
    "docs/architecture/sequence-diagrams.md",
    "docs/architecture/deployment-view.md",
    "docs/architecture/observability.md",
    "docs/architecture/threat-model.md",
    "docs/architecture/large-report-pipeline.md",
    "docs/adr/0006-stream-first-before-platform-complexity.md",
    "docs/events/README.md",
    "docs/security/threat-model.md",
    "docs/security/authorization-matrix.md",
    "docs/security/data-classification.md",
    "docs/security/secrets.md",
    "docs/security/abuse-cases.md",
    "docs/scalability.md",
    "docs/operational-cost.md",
    "docs/architecture/grafana-dashboard.json",
    "docs/benchmarks/methodology.md",
    "docs/runbooks/common-issues.md",
    "docs/runbooks/report-artifact-exposure.md"
  ]

  @required_dirs [
    "docs/adr",
    "docs/api",
    "docs/architecture",
    "docs/benchmarks",
    "docs/diagrams",
    "docs/domain",
    "docs/events",
    "docs/product",
    "docs/runbooks",
    "docs/security",
    "docs/spec-driven",
    "benchmarks/results"
  ]

  @required_readme_headings [
    "## What is this product?",
    "## Problem it solves",
    "## Target users",
    "## Main features",
    "## Architecture overview",
    "## Tech stack",
    "## Domain model",
    "## API documentation",
    "## Async or event architecture",
    "## Database design",
    "## Testing strategy",
    "## Performance benchmarks",
    "## Observability",
    "## Security considerations",
    "## Trade-offs and decisions",
    "## How to run locally",
    "## How to run tests",
    "## Failure scenarios",
    "## Roadmap"
  ]

  @required_openapi_paths [
    "/api/v1/organizations",
    "/api/v1/organizations/me",
    "/api/v1/api-keys",
    "/api/v1/reports",
    "/api/v1/reports/{id}",
    "/api/v1/reports/{id}/events",
    "/api/v1/reports/{id}/download",
    "/api/v1/reports/{id}/cancel",
    "/api/v1/reports/{id}/retry"
  ]

  @required_ci_snippets [
    "Validate repository baseline",
    "mix format --check-formatted",
    "mix compile --warnings-as-errors",
    "mix credo --strict",
    "mix sobelow --ignore Config.HTTPS --skip --exit",
    "mix deps.audit",
    "mix ecto.create && mix ecto.migrate",
    "mix test --cover",
    "mix test --only db",
    "actions/checkout@v6",
    "actions/setup-node@v6",
    "actions/upload-artifact@v7",
    "DavidAnson/markdownlint-cli2-action@v23",
    "@redocly/cli@latest lint openapi.yaml",
    "docker build -t reportforge-ci ."
  ]

  @observability_terms [
    "request ID",
    "correlation ID",
    "metrics",
    "traces",
    "health",
    "readiness",
    "Prometheus",
    "Grafana"
  ]

  @security_terms [
    "tenant API keys",
    "generated report artifacts",
    "signing secret",
    "idempotency keys",
    "rate limiting",
    "signed URLs",
    "tenant-scoped",
    "audit"
  ]

  @required_report_events [
    "requested",
    "started",
    "progress_updated",
    "uploaded",
    "completed",
    "failed",
    "cancelled"
  ]

  @required_spec_driven_sections [
    "## Product Bar",
    "## Domain Bar",
    "## Architecture Bar",
    "## API Bar",
    "## Data and Consistency Bar",
    "## Security Bar",
    "## Observability Bar",
    "## Performance Bar",
    "## Scalability Bar",
    "## Operational Cost Bar",
    "## Maintainability Bar",
    "## Readability Bar",
    "## Test and CI Bar",
    "## Evidence Matrix",
    "## Out of Scope"
  ]

  @required_case_study_sections [
    "## 1. Product Context",
    "## 2. Domain Model",
    "## 3. Architecture",
    "## 4. Key Trade-Offs",
    "## 5. Data Model",
    "## 6. Consistency Model",
    "## 7. Failure Scenarios",
    "## 8. Performance Strategy",
    "## 9. Scalability Strategy",
    "## 10. Security Model",
    "## 11. Observability",
    "## 12. Operational Cost",
    "## 13. Maintainability",
    "## 14. Product Decisions",
    "## 15. What I Would Do Next"
  ]

  test "repository keeps the mandatory structure and populated README sections" do
    Enum.each(@required_files, &assert_file!/1)
    Enum.each(@required_dirs, &assert_dir!/1)

    readme = read_repo!("README.md")

    assert_ordered_substrings!(readme, @required_readme_headings)

    Enum.each(@required_readme_headings, fn heading ->
      assert String.trim(section_body(readme, heading)) != "",
             "#{heading} must contain body content"
    end)
  end

  test "http api contract and example docs satisfy the spec baseline" do
    openapi = read_repo!("openapi.yaml")
    http_examples = read_repo!("docs/api/http-examples.md")
    error_format = read_repo!("docs/api/error-format.md")

    assert String.contains?(openapi, "openapi: 3.0.3")
    assert String.contains?(openapi, "ApiKeyAuth")
    assert String.contains?(openapi, "name: x-api-key")
    assert String.contains?(openapi, "ValidationFailed")
    assert String.contains?(openapi, "Unauthorized")
    assert String.contains?(openapi, "RateLimited")
    assert String.contains?(openapi, "examples:")
    assert String.contains?(openapi, "name: limit")
    assert String.contains?(openapi, "name: cursor")
    assert String.contains?(openapi, "Pagination:")
    assert String.contains?(openapi, "required: [data, meta]")
    assert String.contains?(openapi, "additionalProperties: false")

    Enum.each(@required_openapi_paths, fn path ->
      assert String.contains?(openapi, "#{path}:"),
             "missing required path in openapi.yaml: #{path}"
    end)

    assert String.contains?(http_examples, "## Validation failure example")
    assert String.contains?(http_examples, "## Authorization failure example")
    assert String.contains?(http_examples, "POST /api/v1/reports")
    assert String.contains?(http_examples, "GET /api/v1/reports/rpt_xxx/events")

    assert String.contains?(error_format, "\"code\": \"validation_failed\"")
    assert String.contains?(error_format, "`unauthorized`")
    assert String.contains?(error_format, "`rate_limited`")
  end

  test "spec-driven docs define senior bars, implementation mapping, and verification evidence" do
    senior_spec = read_repo!("docs/spec-driven/senior-readiness-spec.md")
    implementation_plan = read_repo!("docs/spec-driven/implementation-plan.md")
    verification_report = read_repo!("docs/spec-driven/verification-report.md")

    Enum.each(@required_spec_driven_sections, fn section ->
      assert String.contains?(senior_spec, section),
             "senior readiness spec must include #{section}"
    end)

    Enum.each(
      ["## Scope", "## Files to Create or Update", "## Acceptance Criteria Mapping"],
      fn section ->
        assert String.contains?(implementation_plan, section),
               "implementation plan must include #{section}"
      end
    )

    Enum.each(
      ["## Summary", "## Commands Run", "## Passing Criteria", "## Remaining Risk"],
      fn section ->
        assert String.contains?(verification_report, section),
               "verification report must include #{section}"
      end
    )

    Enum.each(
      ["README.md", "docs/product", "docs/domain", "docs/security", "docs/scalability.md"],
      fn evidence ->
        assert String.contains?(senior_spec <> implementation_plan, evidence),
               "spec-driven docs must cite #{evidence}"
      end
    )
  end

  test "product, domain, scalability, cost, and case-study docs satisfy senior rubric" do
    product_docs =
      [
        "docs/product/problem.md",
        "docs/product/personas.md",
        "docs/product/use-cases.md",
        "docs/product/non-goals.md",
        "docs/product/roadmap.md"
      ]
      |> Enum.map_join("\n", &read_repo!/1)

    domain_docs =
      [
        "docs/domain/glossary.md",
        "docs/domain/bounded-contexts.md",
        "docs/domain/aggregates.md",
        "docs/domain/invariants.md",
        "docs/domain/state-machines.md"
      ]
      |> Enum.map_join("\n", &read_repo!/1)

    scalability = read_repo!("docs/scalability.md")
    cost = read_repo!("docs/operational-cost.md")
    case_study = read_repo!("docs/engineering-case-study.md")

    Enum.each(["finance", "tenant", "idempotency", "signed", "retention"], fn term ->
      assert String.contains?(String.downcase(product_docs), term),
             "product docs must mention #{term}"
    end)

    Enum.each(
      ["Organization", "Report", "ReportEvent", "Artifact", "Report State Machine"],
      fn term ->
        assert String.contains?(domain_docs, term),
               "domain docs must mention #{term}"
      end
    )

    Enum.each(
      ["Hot Paths", "Fastest Growing Tables", "Queue Buildup", "Consistency Boundaries"],
      fn term ->
        assert String.contains?(scalability, term),
               "scalability doc must mention #{term}"
      end
    )

    Enum.each(
      ["Infrastructure Components", "Cost Drivers", "Backup And Retention", "Vendor Lock-In"],
      fn term ->
        assert String.contains?(cost, term),
               "operational cost doc must mention #{term}"
      end
    )

    Enum.each(@required_case_study_sections, fn section ->
      assert String.contains?(case_study, section),
             "engineering case study must include #{section}"
    end)
  end

  test "ci workflow covers lint, tests, security, docker, openapi, and coverage" do
    ci_workflow = read_repo!(".github/workflows/ci.yml")
    dockerfile = read_repo!("Dockerfile")
    compose = read_repo!("docker-compose.yml")

    Enum.each(@required_ci_snippets, fn snippet ->
      assert String.contains?(ci_workflow, snippet),
             "CI workflow is missing required step or command: #{snippet}"
    end)

    Enum.each(
      [
        "mix release",
        "USER reportforge",
        "HEALTHCHECK",
        "/readyz",
        "bin/report_forge",
        "sha256:"
      ],
      fn snippet ->
        assert String.contains?(dockerfile, snippet),
               "Dockerfile must include production release hardening: #{snippet}"
      end
    )

    Enum.each(
      [
        "read_only: true",
        "no-new-privileges:true",
        "cap_drop:",
        "pids_limit: 256",
        "mem_limit: 512m",
        "condition: service_healthy"
      ],
      fn snippet ->
        assert String.contains?(compose, snippet),
               "Compose runtime shape must include hardening control: #{snippet}"
      end
    )

    refute String.contains?(dockerfile, ~s(CMD ["mix", "run", "--no-halt"]))
  end

  test "senior hardening gates cover consistency, pagination, rate limiting, and release shape" do
    senior_spec = read_repo!("docs/spec-driven/senior-readiness-spec.md")
    implementation_plan = read_repo!("docs/spec-driven/implementation-plan.md")
    database_design = read_repo!("docs/architecture/database-design.md")
    scalability = read_repo!("docs/scalability.md")

    migration =
      read_repo!(
        "priv/repo/migrations/20260531010000_scope_report_fingerprint_dedupe_to_active_reports.exs"
      )

    Enum.each(
      [
        "No external side effects inside long database transactions",
        "partial active-report fingerprint index",
        "paginated report listings",
        "bounded local rate limiter",
        "container healthcheck",
        "release-based non-root container"
      ],
      fn term ->
        assert String.contains?(
                 senior_spec <> implementation_plan <> database_design <> scalability,
                 term
               ),
               "senior hardening evidence must mention #{term}"
      end
    )

    assert String.contains?(migration, "status IN ('queued', 'running', 'succeeded')")
  end

  test "benchmark docs include all required scenarios and measured result fields" do
    methodology = read_repo!("docs/benchmarks/methodology.md")
    baseline = read_repo!("benchmarks/baseline.md")
    results_path = latest_benchmark_results_readme!()
    results = read_repo!(results_path)

    Enum.each(["smoke.js", "load.js", "stress.js", "spike.js"], fn script_name ->
      assert String.contains?(methodology, script_name),
             "benchmark methodology must mention #{script_name}"
    end)

    Enum.each(["smoke", "load", "stress", "spike"], fn scenario ->
      assert String.contains?(baseline, scenario),
             "benchmark baseline must mention #{scenario}"

      assert String.contains?(results, scenario),
             "benchmark results must include #{scenario}"
    end)

    Enum.each(["p50", "p95", "p99", "Throughput", "Error rate"], fn metric ->
      assert String.contains?(results, metric),
             "benchmark results must include #{metric}"
    end)

    assert String.contains?(results, "CPU")
    assert String.contains?(results, "RSS")
  end

  test "security and observability docs cover the baseline controls" do
    observability = read_repo!("docs/architecture/observability.md")
    threat_model = read_repo!("docs/architecture/threat-model.md")
    financial_threat_model = read_repo!("docs/security/threat-model.md")
    security_auth_matrix = read_repo!("docs/security/authorization-matrix.md")
    data_classification = read_repo!("docs/security/data-classification.md")
    secrets = read_repo!("docs/security/secrets.md")
    abuse_cases = read_repo!("docs/security/abuse-cases.md")
    auth_matrix = read_repo!("docs/api/authorization-matrix.md")
    not_found_normalization = "Cross-tenant report reads are intentionally normalized to `404`"

    Enum.each(@observability_terms, fn term ->
      assert String.contains?(observability, term),
             "observability doc must mention #{term}"
    end)

    Enum.each(@security_terms, fn term ->
      assert String.contains?(threat_model, term),
             "threat model must mention #{term}"
    end)

    Enum.each(["financial exports", "signed URLs", "tenant", "retention", "storage"], fn term ->
      assert String.contains?(financial_threat_model, term),
             "financial threat model must mention #{term}"
    end)

    Enum.each(["signed URL", "tenant", "Artifact", "API key"], fn term ->
      assert String.contains?(
               security_auth_matrix <> data_classification <> secrets <> abuse_cases,
               term
             ),
             "security docs must mention #{term}"
    end)

    assert String.contains?(auth_matrix, "| Endpoint | Auth mode | Scope rule |")
    assert String.contains?(auth_matrix, "`POST /api/v1/reports`")
    assert String.contains?(auth_matrix, "`GET /downloads/{token}`")
    assert String.contains?(auth_matrix, not_found_normalization)
  end

  test "large report pipeline docs cover lifecycle events and deferred platform scope" do
    pipeline = read_repo!("docs/architecture/large-report-pipeline.md")
    events = read_repo!("docs/events/README.md")
    adr = read_repo!("docs/adr/0006-stream-first-before-platform-complexity.md")

    Enum.each(["stream-first", "bounded", "ArtifactStorage", "No new exporters"], fn term ->
      assert String.contains?(pipeline <> adr, term),
             "large report docs must mention #{term}"
    end)

    Enum.each(@required_report_events, fn event ->
      assert String.contains?(events, event),
             "event docs must mention #{event}"
    end)

    Enum.each(["Kubernetes", "data lake", "deferred"], fn term ->
      assert String.contains?(adr, term),
             "ADR 0006 must explain why #{term} is deferred"
    end)
  end

  defp latest_benchmark_results_readme! do
    dated_dir =
      "benchmarks/results"
      |> repo_path()
      |> File.ls!()
      |> Enum.filter(fn entry ->
        full_path = repo_path(Path.join("benchmarks/results", entry))
        File.dir?(full_path) and String.match?(entry, ~r/^\d{4}-\d{2}-\d{2}$/)
      end)
      |> Enum.sort()
      |> List.last()

    assert is_binary(dated_dir), "expected at least one dated benchmark results directory"

    Path.join(["benchmarks/results", dated_dir, "README.md"])
  end

  defp assert_ordered_substrings!(body, required_substrings) do
    {_last_index, _matched} =
      Enum.reduce(required_substrings, {-1, nil}, fn substring, {last_index, _previous} ->
        current_index =
          body
          |> find_index!(substring)

        assert current_index > last_index,
               "#{substring} must appear after the previous required README section"

        {current_index, substring}
      end)
  end

  defp section_body(document, heading) do
    regex = ~r/#{Regex.escape(heading)}\n(?<body>.*?)(?=\n## |\z)/s

    case Regex.run(regex, document, capture: :all_names) do
      [body] -> body
      _ -> flunk("could not extract section for heading #{heading}")
    end
  end

  defp find_index!(body, substring) do
    case :binary.match(body, substring) do
      {index, _length} -> index
      :nomatch -> flunk("missing required content: #{substring}")
    end
  end

  defp assert_file!(path) do
    assert File.regular?(repo_path(path)), "expected file to exist: #{path}"
  end

  defp assert_dir!(path) do
    assert File.dir?(repo_path(path)), "expected directory to exist: #{path}"
  end

  defp read_repo!(path) do
    path
    |> repo_path()
    |> File.read!()
  end

  defp repo_path(path) do
    Path.join(@repo_root, path)
  end
end
