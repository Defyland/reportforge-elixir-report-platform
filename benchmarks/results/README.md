# Benchmark Results

This folder stores captured benchmark outputs, methodology notes, and environment details for each benchmark run.

Suggested filename format:

- `2026-05-28-smoke.md`
- `2026-05-28-load.md`
- `2026-05-28-stress.md`
- `2026-05-28-spike.md`

Each result file should include:

- git commit SHA
- environment details
- request mix and tenant setup
- `p50`, `p95`, `p99`, throughput, and error rate
- notes about queue depth, retries, and memory growth
