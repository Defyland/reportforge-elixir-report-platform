# Threat Model

## Primary assets

- tenant API keys
- tenant report definitions and filters
- generated report artifacts
- lifecycle event history
- signing secret used for artifact URLs

## Main threats

## Credential leakage

Risk:

- attacker obtains an API key and impersonates a tenant

Current mitigations:

- hashed API-key secret storage
- revocation support
- tenant scoping on all authenticated endpoints
- durable audit records for organization bootstrap, API-key issuance, and API-key revocation

Remaining work:

- external managed secret storage
- key rotation workflows

## Cross-tenant data access

Risk:

- one tenant reads or manipulates another tenant's report

Current mitigations:

- every report lookup is scoped by `organization_id`
- signed download tokens include report and organization context
- foreign-tenant reads return `404`

## Replay and duplicate submission

Risk:

- clients retry aggressively and create duplicate long-running reports

Current mitigations:

- idempotency keys
- tenant-scoped fingerprint deduplication
- rate limiting for public and tenant write flows

## Artifact URL abuse

Risk:

- leaked download URLs are reused outside the intended window

Current mitigations:

- signed URLs
- explicit expiration timestamps
- recurring cleanup of expired artifacts

Remaining work:

- object storage with short-lived signed URLs

## Upstream and storage failure

Risk:

- source queries or storage writes fail mid-execution

Current mitigations:

- report lifecycle includes `failed`
- failure scenario tests exist
- retry path exists
- recurring cleanup has dedicated runbook coverage for database-dependent failures

Remaining work:

- DLQ or retry semantics if a broker is introduced
- recovery runbooks for dependency outages
