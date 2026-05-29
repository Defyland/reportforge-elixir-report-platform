# Architecture Overview

ReportForge is currently a modular Elixir API with four main layers:

1. HTTP edge: `ReportForgeWeb.Router`, request context, auth, and error envelopes.
2. Identity domain: tenant registration, bootstrap API keys, API-key issuance, and revocation.
3. Reporting domain: lifecycle state machine, deduplication, event stream, artifact metadata, and signed URLs.
4. Runtime primitives: PostgreSQL-backed persistence, Oban-backed durable jobs, rate limiter, and metrics collection.

## Current request flow

- request enters through Bandit/Plug
- request, correlation, and trace IDs are attached
- authenticated endpoints validate the API key and apply rate limiting
- the domain layer mutates transactional state through `ReportForge.Repo`
- long-running report work is delegated to an Oban job with propagated trace context
- metrics and structured logs record the result

## Planned evolution

- move artifacts from memory to MinIO or S3
- add collector-backed metric export and validate dashboards against emitted telemetry
