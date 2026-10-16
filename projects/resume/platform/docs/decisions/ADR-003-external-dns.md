# ADR-003 — Use existing external DNS

**Status:** Accepted

## Decision
Use the domain registrar/existing DNS host rather than creating an Azure DNS zone.

## Rationale
Static Web Apps supports custom domains managed by external DNS providers and automatically provisions TLS. Azure DNS would introduce a small but unnecessary Azure charge for this workload.
