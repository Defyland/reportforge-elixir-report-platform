# State Machines

## Report State Machine

| From | Event or action | To | Notes |
| --- | --- | --- | --- |
| none | `POST /api/v1/reports` accepted | `queued` | Emits `report.requested`. |
| `queued` | Oban worker starts | `running` | Emits `report.started`. |
| `running` | bounded work completes | `running` | Emits `report.progress_updated`. |
| `running` | artifact bytes written | `running` | Emits `report.uploaded`. |
| `running` | metadata persisted and workflow completes | `succeeded` | Emits `report.completed`. |
| `queued` or `running` | cancel request accepted | `cancelled` | Emits `report.cancelled`. |
| `running` | definitive failure or retry exhaustion | `failed` | Emits `report.failed`. |
| `failed` or `cancelled` | retry request accepted | `queued` | Emits a retry audit event and schedules a new job. |

## Canonical Lifecycle Events

- `report.requested`
- `report.started`
- `report.progress_updated`
- `report.uploaded`
- `report.completed`
- `report.failed`
- `report.cancelled`

The executable proof is in `test/report_forge/reports/worker_test.exs`, which
asserts the success lifecycle and metadata carried by progress and upload
events.
