# Error Format

All non-success responses use the same envelope:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Request body contains invalid fields.",
    "retryable": false,
    "details": [
      {
        "field": "format",
        "issue": "must be one of csv, json, zip"
      }
    ]
  },
  "meta": {
    "request_id": "req_abc123",
    "correlation_id": "cor_abc123",
    "timestamp": "2026-05-28T21:00:00Z"
  }
}
```

## Common error codes

- `unauthorized`: API key is missing, malformed, revoked, or invalid
- `validation_failed`: request payload failed field-level validation
- `bad_request`: required wrapper objects such as `organization` or `report` were missing
- `not_found`: resource does not exist or belongs to another tenant
- `conflict`: action is invalid for the resource's current lifecycle state
- `artifact_expired`: signed download URL is no longer valid
- `rate_limited`: in-memory fixed-window rate limit was exceeded

## Notes

- `request_id` identifies a specific HTTP request.
- `correlation_id` links related work across the async report lifecycle.
- `retryable` indicates whether a caller should retry automatically.
- `details` is empty when no field-specific issue list exists.
