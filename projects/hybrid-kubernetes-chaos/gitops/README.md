# Hybrid Kubernetes GitOps

This directory is the reconciliation target for the physical `k8s-edge-01` Kubernetes cluster connected to Azure through Azure Arc.

## Current workload

The initial desired state is intentionally small and inexpensive:

- `hybrid-lab` namespace
- two-replica NGINX deployment
- custom landing page from a ConfigMap
- internal `ClusterIP` service
- readiness/liveness probes and small CPU/memory limits

The two replicas give the later chaos-engineering work something meaningful to disrupt while keeping the footprint tiny on the single-node lab.

## Azure Arc / Flux configuration

Create the Flux configuration from a Windows PowerShell session authenticated to the portfolio subscription:

```powershell
az k8s-configuration flux create `
  --resource-group rg-k8s-hybrid-lab `
  --cluster-name k8s-edge-01 `
  --cluster-type connectedClusters `
  --name hybrid-lab-gitops `
  --namespace hybrid-gitops `
  --scope cluster `
  --url https://github.com/HoldenJolley/Azure-Solution-Architect-Portfolio `
  --branch main `
  --kustomization name=hybrid-lab path=./projects/hybrid-kubernetes-chaos/gitops prune=true
```

The Flux extension controllers run in `flux-system`; the Azure Arc Flux configuration objects are kept separately in `hybrid-gitops`.

`prune=true` makes Git the authoritative desired state: resources removed from this path are removed from the cluster during reconciliation.

## Validate reconciliation

```powershell
az k8s-configuration flux show `
  --resource-group rg-k8s-hybrid-lab `
  --cluster-name k8s-edge-01 `
  --cluster-type connectedClusters `
  --name hybrid-lab-gitops `
  --output table

kubectl get all -n hybrid-lab
```

To test the workload locally without exposing it to the LAN or internet:

```powershell
kubectl port-forward -n hybrid-lab service/hybrid-demo 8080:80
```

Then browse to `http://localhost:8080`.

## Next stages

The GitOps base is intended to grow into the hybrid chaos demo with network policy, observability, controlled failure scenarios, recovery validation, and Azure-side governance while keeping the physical cluster as the execution environment.
