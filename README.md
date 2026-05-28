# ReportForge

Massive financial reporting platform built in Elixir to showcase stream-first exports and long-running job execution.

## Status

Phase 0 bootstrap only. This repository currently establishes naming, scope, documentation structure, and engineering expectations. It does not yet contain a Phoenix application, Oban workers, or storage integration scaffolding.

## Product intent

ReportForge is planned as an asynchronous reporting platform for large financial exports, focused on generating CSV, JSON, ZIP, and later XLSX or PDF outputs without exhausting memory or impacting the primary transactional application.

## Planned stack

- Elixir
- Phoenix API
- PostgreSQL
- Oban
- MinIO or S3
- OpenTelemetry
- Prometheus and Grafana
- Docker Compose
- k6

## Engineering focus

This project is meant to demonstrate:

- stream-first file generation with bounded memory usage
- long-running jobs with retry, cancellation, and supervision
- progress tracking and report lifecycle control
- object-storage upload flows without materializing large files in RAM
- idempotent report creation and deduplication
- performance and failure testing for large exports

## Bootstrap contents

- repository initialized and synchronized with GitHub
- mandatory documentation folders created
- baseline engineering spec captured in `docs/engineering-baseline.md`

## Next phase

The first implementation slice should prioritize report requests, lifecycle states, CSV and JSON streaming, ZIP packaging, progress telemetry, storage upload, and idempotency controls.
