# Non-Goals

ReportForge intentionally keeps the current scope narrow so the repository can
show production judgment without pretending to be a complete enterprise data
platform.

## Current Non-Goals

- Implementing new exporters in this documentation pass.
- Replacing finance source systems or becoming the system of record.
- Becoming a BI dashboard, warehouse, lakehouse, or data lake ingestion layer.
- Shipping Kubernetes, Helm, Terraform, or cloud-specific infrastructure before
  workload and deployment constraints are known.
- Implementing role-based access control beyond tenant-scoped API keys.
- Supporting browser-facing file previews or collaborative report editing.
- Guaranteeing production SLOs without real deployment telemetry and traffic.

## Reasoning

The current repository focuses on the hardest backend concerns that can be
proven locally: async lifecycle, idempotency, tenant isolation, storage
boundaries, signed access, observability, tests, and operational documentation.
Infrastructure specialization belongs after the target runtime is chosen.
