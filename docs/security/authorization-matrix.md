# Security Authorization Matrix

This document mirrors the API-focused matrix in
[docs/api/authorization-matrix.md](../api/authorization-matrix.md) and adds the
security interpretation for financial exports.

| Capability | Auth mode | Tenant rule | Sensitive outcome |
| --- | --- | --- | --- |
| Create organization | Public, rate limited | Creates a new tenant | Issues bootstrap API key once. |
| Read organization | `x-api-key` | Current API-key tenant only | Confirms tenant scope. |
| Manage API keys | `x-api-key` | Current tenant only | Creates or revokes tenant credentials. |
| Create report | `x-api-key` plus idempotency | Current tenant only | Schedules financial export work. |
| Read report | `x-api-key` | Report must belong to tenant | Avoids cross-tenant metadata leakage. |
| Read report events | `x-api-key` | Report must belong to tenant | Exposes lifecycle metadata, not rows. |
| Retry or cancel report | `x-api-key` | Report must belong to tenant | Mutates report state and audit trail. |
| Request download URL | `x-api-key` | Completed report must belong to tenant | Creates a short-lived signed URL. |
| Resolve signed download | Signed token | Token, tenant, report, artifact, and expiry must match | Streams or redirects artifact bytes. |

## Security Rules

- Cross-tenant report reads are intentionally normalized to `404`.
- API keys are tenant credentials, not user-level RBAC.
- Signed URLs are bearer capabilities and must be short-lived.
- Lifecycle events must not contain API keys, signed URLs, or financial rows.
- Audit logs are required for privileged report and key actions.
