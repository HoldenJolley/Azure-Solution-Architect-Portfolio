# ADR-003: Azure Container Apps

**Decision:** Use a VNet-integrated workload-profile Container Apps environment for gateway and customer inference containers.

**Rationale:** It supports managed identities, private networking, autoscaling, separate ingress boundaries, and a confidential-compute extension without operating AKS.

**Consequence:** Workloads must conform to Container Apps constraints and private image-pull networking.
