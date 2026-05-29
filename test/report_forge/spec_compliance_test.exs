defmodule ReportForge.SpecComplianceTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  @required_files [
    "README.md",
    "openapi.yaml",
    ".github/workflows/ci.yml",
    "benchmarks/baseline.md",
    "docs/api/error-format.md",
    "docs/api/http-examples.md",
    "docs/api/authorization-matrix.md",
    "docs/architecture/observability.md",
    "docs/architecture/threat-model.md",
    "docs/architecture/grafana-dashboard.json",
    "docs/benchmarks/methodology.md",
    "docs/runbooks/common-issues.md"
  ]

  @required_dirs [
    "docs/adr",
    "docs/api",
    "docs/architecture",
    "docs/benchmarks",
    "docs/diagrams",
    "docs/runbooks",
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
    "mix sobelow --skip --exit",
    "mix deps.audit",
    "mix ecto.create && mix ecto.migrate",
    "mix test --cover",
    "mix test --only db",
    "actions/upload-artifact@v4",
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

  test "ci workflow covers lint, tests, security, docker, openapi, and coverage" do
    ci_workflow = read_repo!(".github/workflows/ci.yml")

    Enum.each(@required_ci_snippets, fn snippet ->
      assert String.contains?(ci_workflow, snippet),
             "CI workflow is missing required step or command: #{snippet}"
    end)
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

    assert String.contains?(auth_matrix, "| Endpoint | Auth mode | Scope rule |")
    assert String.contains?(auth_matrix, "`POST /api/v1/reports`")
    assert String.contains?(auth_matrix, "`GET /downloads/{token}`")
    assert String.contains?(auth_matrix, not_found_normalization)
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
