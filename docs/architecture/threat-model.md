# Threat Model

This architecture-level model summarizes system risks. The focused financial
export model lives in [docs/security/threat-model.md](../security/threat-model.md)
and covers signed URLs, retention, tenant access, and object storage in more
detail.

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
- tokens include report and organization context
- explicit expiration timestamps
- recurring cleanup of expired artifacts
- object storage keys are not treated as public identifiers

Remaining work:

- managed signing-secret rotation
- sensitivity-based download TTLs
- bucket lifecycle policy in the target cloud provider

## Retention failure

Risk:

- financial exports outlive tenant policy or legal retention requirements

Current mitigations:

- report artifacts have explicit expiration timestamps
- cleanup workers delete expired metadata and storage objects
- artifact exposure runbook documents emergency response

Remaining work:

- cloud object lifecycle enforcement
- backup and restore drills for retention-sensitive data
- legal hold rules if required by the deployment context

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

## Event data leakage

Risk:

- lifecycle events accidentally include report row contents, credentials, signed
  URLs, or other financial data

Current mitigations:

- event docs restrict payloads to lifecycle metadata
- signed URLs are explicitly excluded from durable event facts
- correlation and trace IDs support debugging without exposing report contents

Remaining work:

- schema validation for future event publishers
