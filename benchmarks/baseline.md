# ReportForge Benchmark Baseline

This repository defines four mandatory k6 benchmark profiles for the first executable slice:

1. `smoke.js`: verify health, readiness, report creation, and download-link generation under light traffic.
2. `load.js`: sustained tenant traffic against `POST /api/v1/reports` and `GET /api/v1/reports/{id}`.
3. `stress.js`: push the Oban-backed execution pipeline until queue latency and error rate rise.
4. `spike.js`: abrupt tenant bursts to validate rate limiting, queue growth, and recovery.

## Current phase scope

- The current executable slice uses PostgreSQL-backed state and Oban-backed execution, so benchmark results should reflect the durable request path rather than a purely in-memory simulation.
- The scripts expect a pre-created organization and bootstrap API key exported as environment variables.
- The performance target is evidence, not absolute throughput claims, until object storage and production telemetry export are added.

## Metrics to capture

- `p50`, `p95`, and `p99` latency
- request throughput
- error rate
- deduplication hit rate
- report completion duration
- process memory growth notes during CSV, JSON, and ZIP generation

## Acceptance targets for Phase 1

- `POST /api/v1/reports` under load should remain below `p95 <= 150 ms`
- `GET /api/v1/reports/{id}` under load should remain below `p95 <= 80 ms`
- error rate should stay below `1%` for the happy path benchmark
- deduplicated retries should remain consistent under parallel submission
