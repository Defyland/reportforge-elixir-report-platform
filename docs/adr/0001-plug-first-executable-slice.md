# ADR 0001: Plug-First Executable Slice

## Status

Accepted

## Context

ReportForge needs a real HTTP API quickly, but the current objective is to prove the product workflow and technical narrative before durable infrastructure exists.

## Decision

Build the first executable slice with Bandit + Plug instead of a full Phoenix application.

## Consequences

- smaller bootstrapping surface and fewer generated files
- easier to keep the first slice focused on request/async domain behavior
- fewer batteries than Phoenix for future admin UI or richer controller ergonomics
- a future migration to Phoenix remains possible without changing the core domain modules
