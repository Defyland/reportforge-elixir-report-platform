# Benchmark Methodology

## Goals

- measure request latency for report acceptance and lookup
- observe queue growth and completion timing under sustained write pressure
- verify rate limiting and deduplication behavior during bursty traffic
- capture memory notes for CSV, JSON, and ZIP generation paths

## Environment guidance

- run against a local or isolated environment with a single tenant
- export `BASE_URL` and `BOOTSTRAP_API_KEY`
- record Elixir, Erlang, CPU, memory, and Docker versions
- note whether the run used native `mix run` or a container image

## Profiles

- `smoke.js`: correctness and endpoint availability
- `load.js`: steady-state request acceptance
- `stress.js`: saturation behavior and queue depth
- `spike.js`: sudden bursts and recovery

## Output template

- date and commit SHA
- benchmark script name
- VUs, duration, and threshold config
- `p50`, `p95`, `p99`, throughput, error rate
- operator notes about memory, retries, or timeouts
