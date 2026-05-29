# HTTP Examples

## Create organization

```http
POST /api/v1/organizations
Content-Type: application/json

{
  "organization": {
    "name": "Treasury Labs",
    "slug": "treasury-labs",
    "retention_days": 45
  }
}
```

```json
{
  "data": {
    "organization": {
      "id": "org_xxx",
      "name": "Treasury Labs",
      "slug": "treasury-labs",
      "retention_days": 45,
      "inserted_at": "2026-05-28T21:00:00Z",
      "updated_at": "2026-05-28T21:00:00Z"
    },
    "bootstrap_api_key": "rfk_ab12cd34.secret",
    "api_key": {
      "id": "key_xxx",
      "name": "bootstrap",
      "key_prefix": "ab12cd34",
      "token_hint": "cret",
      "last_used_at": null,
      "revoked_at": null,
      "inserted_at": "2026-05-28T21:00:00Z",
      "updated_at": "2026-05-28T21:00:00Z"
    }
  },
  "meta": {
    "request_id": "req_xxx",
    "correlation_id": "cor_xxx",
    "timestamp": "2026-05-28T21:00:00Z"
  }
}
```

## Create report

```http
POST /api/v1/reports
Content-Type: application/json
x-api-key: rfk_ab12cd34.secret

{
  "report": {
    "template_name": "cash_position",
    "format": "csv",
    "requested_by": "analyst@example.com",
    "idempotency_key": "cash-position-2026-05-28",
    "filters": {
      "row_limit": 5,
      "currency": "USD"
    }
  }
}
```

```json
{
  "data": {
    "id": "rpt_xxx",
    "template_name": "cash_position",
    "format": "csv",
    "status": "queued",
    "progress_pct": 0,
    "attempt_count": 1,
    "artifact": null,
    "error": null
  },
  "meta": {
    "request_id": "req_xxx",
    "correlation_id": "cor_xxx",
    "timestamp": "2026-05-28T21:01:00Z",
    "deduplicated": false
  }
}
```

## List report events

```http
GET /api/v1/reports/rpt_xxx/events
x-api-key: rfk_ab12cd34.secret
```

```json
{
  "data": [
    {
      "event_type": "report.requested",
      "status": "queued",
      "progress_pct": 0
    },
    {
      "event_type": "report.started",
      "status": "running",
      "progress_pct": 10
    },
    {
      "event_type": "report.completed",
      "status": "succeeded",
      "progress_pct": 100
    }
  ]
}
```

## Resolve download link

```http
GET /api/v1/reports/rpt_xxx/download
x-api-key: rfk_ab12cd34.secret
```

```json
{
  "data": {
    "report_id": "rpt_xxx",
    "url": "http://localhost:4000/downloads/...",
    "filename": "cash_position-1716930060.csv",
    "content_type": "text/csv",
    "expires_at": "2026-05-29T21:01:00Z"
  }
}
```

## Validation failure example

```http
POST /api/v1/reports
Content-Type: application/json
x-api-key: rfk_ab12cd34.secret

{
  "report": {
    "template_name": "cash_position",
    "format": "xml",
    "requested_by": "ops@example.com"
  }
}
```

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
  }
}
```

## Authorization failure example

```http
GET /api/v1/reports/rpt_xxx
```

```json
{
  "error": {
    "code": "unauthorized",
    "message": "API key is missing or invalid.",
    "retryable": false,
    "details": []
  }
}
```
