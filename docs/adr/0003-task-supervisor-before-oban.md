# ADR 0003: Task.Supervisor Before Oban

## Status

Superseded by [ADR 0004](./0004-adopt-oban-for-durable-execution.md)

## Context

The first slice must show asynchronous execution, cancellation, retries, and lifecycle events, but the repository does not yet include PostgreSQL or durable job storage.

## Decision

Use `Task.Supervisor` for the initial async execution path and reserve Oban for the persistence phase.

## Consequences

- report execution can be demonstrated immediately
- task state is not durable across process restarts
- cancellation semantics are simpler but less production-ready than Oban
- the domain contract is shaped so execution can later move behind an Oban worker boundary
