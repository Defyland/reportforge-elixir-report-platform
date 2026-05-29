# Authorization Matrix

| Endpoint | Auth mode | Scope rule |
| --- | --- | --- |
| `POST /api/v1/organizations` | public | rate limited by client IP |
| `GET /api/v1/organizations/me` | API key | tenant can only inspect itself |
| `GET /api/v1/api-keys` | API key | tenant can only list its own keys |
| `POST /api/v1/api-keys` | API key | tenant can only issue keys for itself |
| `DELETE /api/v1/api-keys/{id}` | API key | tenant can only revoke its own keys |
| `GET /api/v1/reports` | API key | tenant can only list its own reports |
| `POST /api/v1/reports` | API key | tenant can only create reports under its own scope |
| `GET /api/v1/reports/{id}` | API key | tenant can only read its own report |
| `GET /api/v1/reports/{id}/events` | API key | tenant can only read its own report events |
| `GET /api/v1/reports/{id}/download` | API key | tenant can only resolve a download link for its own report |
| `POST /api/v1/reports/{id}/cancel` | API key | tenant can only cancel its own queued or running report |
| `POST /api/v1/reports/{id}/retry` | API key | tenant can only retry its own failed or cancelled report |
| `GET /downloads/{token}` | signed URL | access is constrained by signature and expiry rather than API key |

## Notes

- The current slice has no operator JWT flow.
- If an admin or support surface is added later, JWT or session-based auth should be documented separately.
- Cross-tenant report reads are intentionally normalized to `404` instead of leaking existence through `403`.
