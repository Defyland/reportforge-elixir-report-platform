# Report Artifact Exposure

Use this runbook when a generated report artifact or signed URL may have been exposed to the wrong tenant or for too long.

## Triage

- Identify the `report_id`, `organization_id`, artifact key, and signed URL expiry.
- Check audit logs for download events and API key identity.
- Confirm the report filters and tenant scope used during generation.
- Determine whether the URL was still valid when reported.

## Recovery

- Revoke or rotate the signing secret if URL signing was compromised.
- Expire the affected artifact metadata and remove the object from storage.
- Regenerate the report after verifying tenant scope.
- Add a failure drill if the exposure came from retention or storage policy drift.
