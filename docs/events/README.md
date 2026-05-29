# ReportForge Event Contracts

ReportForge lifecycle events document the internal contract for large report
pipelines. They are used for report timelines, operator debugging, progress
views, retries, audit correlation, and future notification delivery. They are
not exporters, webhooks, or a data-lake ingestion mechanism.

## Envelope

Every report event must include:

- `event_id`
- `event_type`
- `schema_version`
- `occurred_at`
- `producer`
- `organization_id`
- `report_id`
- `correlation_id`
- `payload`

## Lifecycle events

| Semantic event | Wire event type | Producer moment | Required payload | Notes |
| --- | --- | --- | --- | --- |
| `requested` | `report.requested` | API accepts a non-duplicate report request | `template_name`, `format`, `requested_by`, `idempotency_key` | Must not include source row data. |
| `started` | `report.started` | Oban worker begins execution | `attempt`, `max_attempts` | First worker-side event. |
| `progress_updated` | `report.progress_updated` | Worker completes a bounded unit of work | `stage`, `progress_pct`, `rows_processed` | May be emitted more than once for the same stage. |
| `uploaded` | `report.uploaded` | Artifact bytes are durably written to storage | `storage_key`, `byte_size`, `checksum`, `content_type` | Must not include signed URL. |
| `completed` | `report.completed` | Report reaches terminal success | `row_count`, `byte_size`, `checksum` | Consumers should fetch current report state before download. |
| `failed` | `report.failed` | Report reaches terminal failure or retry exhaustion | `error_code`, `retryable`, `attempt` | Error messages should avoid sensitive data. |
| `cancelled` | `report.cancelled` | User or operator cancels queued/running work | `cancelled_by`, `previous_status` | Cancellation is terminal unless retried. |

## Compatibility policy

- Consumers deduplicate by `event_id`.
- `schema_version` increments only for incompatible changes.
- New nullable payload fields are backward compatible.
- Progress events may be emitted more than once for the same percentage.
- Download URLs are not event facts and must not be stored as durable state.
- Artifact storage keys can appear in payloads; signed URLs must not.
- Financial row contents, credentials, API keys, and signed tokens must never be
  emitted in events.

## Large report guidance

- Emit progress from bounded chunks, not from every row.
- Prefer stage names that operators can reason about, such as `query`,
  `serialize`, `upload`, and `finalize`.
- Keep event payloads small enough for database-backed timelines and future
  notification delivery.
- Treat events as lifecycle metadata, not as an analytical event stream.

Schema examples:

- [report_lifecycle_event.v1.json](report_lifecycle_event.v1.json)
- [report_progress_updated.v1.json](report_progress_updated.v1.json)
