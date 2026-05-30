# Abuse Cases

## Cross-Tenant Report Enumeration

An attacker guesses report IDs from another tenant. Current control:
tenant-scoped lookup with normalized `404` responses.

## Signed URL Leakage

A valid signed URL is forwarded outside the intended tenant. Current control:
short-lived tokens that resolve through artifact metadata and expiry.

## Replay Of Report Requests

A client repeatedly submits the same expensive report. Current control:
idempotency keys, fingerprint deduplication, database constraints, and rate
limiting.

## Public Bucket Misconfiguration

Object storage is configured with public reads. Current control:
authorization is still based on PostgreSQL metadata and signed URL resolution.
Future hardening should add bucket policy drift detection.

## Event Payload Data Leak

Report lifecycle events include financial rows, API keys, or signed URLs.
Current control: event contract forbids sensitive values; future hardening
should add event payload schema allowlists.

## Retention Bypass

Financial artifacts remain available beyond the tenant retention window. Current
control: expiry metadata and scheduled cleanup jobs. Future hardening should add
provider lifecycle policies and reconciliation.

## Worker Resource Exhaustion

Large reports consume excessive memory or queue capacity. Current control:
stream-first design is documented as the required exporter direction before new
large templates are added.
