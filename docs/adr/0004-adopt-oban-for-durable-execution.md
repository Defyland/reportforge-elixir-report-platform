# ADR 0004: Adopt Oban for Durable Execution

## Status

Accepted

## Context

The repository already moved the main report lifecycle to PostgreSQL, but async execution still needed to survive process restarts, support durable cancellation and retry semantics, and align the runtime with the platform spec's expectation of a production-ready background execution layer.

## Decision

Adopt Oban as the report execution engine, backed by the existing PostgreSQL database.

## Consequences

- report creation now persists a real job alongside transactional report state
- queued work survives API process restarts
- cancellation and retry flows operate against durable job records
- test coverage can assert queue insertion and manual draining without relying on process-local tasks
- future recurring cleanup jobs and retry policies can be built on the same execution substrate
