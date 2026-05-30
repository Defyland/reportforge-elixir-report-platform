# Data Classification

| Data | Classification | Storage | Notes |
| --- | --- | --- | --- |
| API key secret | Secret | Digest in PostgreSQL; clear value shown once | Must not be logged or returned again. |
| Signing secret | Secret | Environment variable or secret file | Future work: managed secret store and rotation. |
| Report filters | Confidential tenant data | PostgreSQL | May reveal financial scope or date ranges. |
| Generated artifacts | Restricted financial data | Artifact storage adapter | Controlled by signed URLs and retention. |
| Artifact metadata | Confidential operational data | PostgreSQL | Includes storage key, checksum, byte size, content type, expiry. |
| Report events | Internal operational data | PostgreSQL | Must not include financial rows or signed URLs. |
| Audit logs | Confidential security data | PostgreSQL | Used for investigation and compliance. |
| Metrics | Internal operational data | `/metrics` and Prometheus | Should avoid tenant-identifying labels. |
| Traces and logs | Internal operational data | Console or OTLP collector | Must avoid credentials and row contents. |

## Handling Rules

- Financial artifact bytes should live outside PostgreSQL.
- PostgreSQL remains the authorization and metadata source of truth.
- Signed URLs should expire before long-term retention boundaries.
- Sensitive tokens and secrets should never be event payloads.
- Production deployments should enforce encryption, backup, and retention
  policies at the storage provider.
