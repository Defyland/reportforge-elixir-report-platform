# Product Roadmap

## Now

- Tenant-scoped API-key authentication.
- Async report lifecycle backed by PostgreSQL and Oban.
- Idempotent report creation through key and fingerprint controls.
- Local and S3-compatible artifact storage adapters.
- Signed downloads, report events, audit logs, retention cleanup, metrics, and
  traces.

## Next

- Stream-first exporters for bounded memory on larger datasets.
- Stronger retry classification by source, serializer, storage, and terminal
  validation failures.
- Reconciliation job for orphaned storage objects and metadata mismatches.
- More explicit queue and worker capacity controls.
- Deployment-specific alert routing and SLO dashboards.

## Later

- Managed cloud provisioning after the target runtime is selected.
- Secret-manager-backed signing rotation and API-key operational tooling.
- Advanced templates such as XLSX or PDF when product demand justifies them.
- Data lake or CDC integration only if the product becomes an analytical data
  distribution service.
