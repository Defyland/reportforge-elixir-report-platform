# Pricing Or Plans

ReportForge is not a billing product in this repository. This document uses
"plans" to describe operating tiers that a production owner would use to bound
cost, retention, and support expectations.

| Plan | Intended user | Example limits | Operational reason |
| --- | --- | --- | --- |
| Internal | One finance team | small templates, short retention, local storage in dev | Keeps the executable slice simple. |
| Department | Multiple finance workflows | larger artifacts, S3-compatible storage, scheduled cleanup | Separates storage bytes from database pressure. |
| Enterprise | Regulated financial exports | tighter signed URL TTL, audit review, bucket policy, alerting | Supports stronger compliance and incident response. |

## Current Repository Scope

The code implements tenant retention metadata and signed artifact access, but it
does not enforce commercial plan limits. Quotas, billing, and paid-plan
entitlements are deferred until there is a product requirement.
