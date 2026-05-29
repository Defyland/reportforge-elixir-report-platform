# Benchmark Results Status

## Current state

- benchmark scripts exist
- methodology is documented
- a first measured benchmark capture is committed under [benchmarks/results/2026-05-29](../../benchmarks/results/2026-05-29/README.md)

## What is now proven

- smoke, load, stress, and spike runs have been executed against the local PostgreSQL + Oban runtime
- the default tenant write limit meaningfully constrains the happy-path load profile and produces `429` saturation
- a benchmark-specific runtime profile can sustain the scripted load target while staying below the latency threshold
- the committed result set now includes explicit `p50`, `p95`, and `p99` latency evidence
- a profiled spike run now includes basic CPU and RSS notes for the Elixir runtime

## Remaining follow-up

- rerun under Docker or CI once a daemon-backed environment is available
- repeat after container-backed object storage and production telemetry export are added
