# Benchmark Capture 2026-05-29

- git SHA: `4dd12875084892646de05289ad369ed9e3b25118`
- base URL: `http://127.0.0.1:4000`
- database: local PostgreSQL on port `55432`
- tenant setup: one benchmark organization with one bootstrap API key

## Runtime profiles used

- Default profile:
  - used for `smoke` and the first `load` capture
  - rate limits remained at the product defaults
- Benchmark profile:
  - used for `load-benchmark`, `stress`, `spike`, and `spike-profiled`
  - server env overrides:
    - `REPORT_FORGE_PUBLIC_WRITE_LIMIT=5000`
    - `REPORT_FORGE_TENANT_READ_LIMIT=5000`
    - `REPORT_FORGE_TENANT_WRITE_LIMIT=5000`

## Result summary

| Scenario | Profile | p50 | p95 | p99 | Throughput | Error rate | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `smoke` | benchmark-compatible | `4.92 ms` | `35.84 ms` | `41.01 ms` | `1.95 req/s` | `0.00%` | 5 iterations, 100% checks passed |
| `load` | default | `6.91 ms` | `13.12 ms` | n/a | `19.63 req/s` | `91.01%` | default tenant write limit produced `429` saturation |
| `load` | benchmark | `10.93 ms` | `15.18 ms` | `23.03 ms` | `19.51 req/s` | `0.00%` | passed the scripted happy-path thresholds |
| `stress` | benchmark | `2.35 ms` | `6.34 ms` | `9.32 ms` | `8219.13 req/s` | `0.00%` | `429` counted as expected for saturation semantics |
| `spike` | benchmark | `6.74 ms` | `14.50 ms` | `28.10 ms` | `238.08 req/s` | `0.00%` | burst to 80 VUs completed without failed checks |

## CPU and memory note

The profiled spike run sampled the Elixir `beam.smp` process once per second:

- samples: `50`
- max CPU: `103.00%`
- avg CPU: `39.34%`
- max RSS: `83,792 KB` (`81.83 MiB`)
- avg RSS: `63,820.80 KB` (`62.32 MiB`)

## Artifacts in this folder

- `smoke-output.txt`
- `smoke-summary.json`
- `load-default-rate-limit-output.txt`
- `load-default-rate-limit-summary.json`
- `load-benchmark-output.txt`
- `load-benchmark-summary.json`
- `stress-output.txt`
- `stress-summary.json`
- `stress-legacy-output.txt`
- `stress-legacy-summary.json`
- `spike-output.txt`
- `spike-summary.json`
- `spike-profiled-output.txt`
- `spike-profiled-summary.json`
- `spike-process-samples.txt`
- `spike-process-summary.txt`

## Follow-up still required

- repeat the suite under Docker or CI once the daemon is available
- rerun after object storage and official telemetry export land
