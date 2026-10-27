# Hybrid Kubernetes GitOps

This directory is the reconciliation target for the physical `k8s-edge-01` Kubernetes cluster connected to Azure through Azure Arc.

## Current workload

The desired state remains intentionally small and inexpensive:

- `hybrid-lab` namespace
- three-replica NGINX `hybrid-demo` Deployment
- custom landing page from a ConfigMap
- internal `hybrid-demo` ClusterIP Service
- readiness/liveness probes and small CPU/memory limits
- one-replica read-only `hybrid-status-api` for the interactive dashboard

The three application replicas provide enough redundancy for controlled pod-level failure testing while keeping the footprint tiny on the single-node lab. The status API is separate from the application workload so dashboard observation does not require exposing the Kubernetes API itself.

## Read-only status API

`status-api/` contains the first backend for `chaos.holdenjolley.com`.

It exposes only:

- `GET /healthz`
- `GET /api/status`

The API reads the `hybrid-demo` Deployment and pods, node `k8s-edge-01`, Kubernetes version, Flux Kustomization status, optional pod metrics, and direct Service reachability. Its service account has no Kubernetes mutation permissions.

The internal Service is:

```text
hybrid-status-api.hybrid-lab.svc.cluster.local
```

For local validation:

```powershell
kubectl get deployment,service,pod -n hybrid-lab -l app.kubernetes.io/name=hybrid-status-api
kubectl port-forward -n hybrid-lab service/hybrid-status-api 8081:80
```

Then from another PowerShell window:

```powershell
Invoke-RestMethod http://127.0.0.1:8081/healthz
$status = Invoke-RestMethod http://127.0.0.1:8081/api/status
$status | ConvertTo-Json -Depth 10
```

See `status-api/README.md` for the response boundary and RBAC proof checks.

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

To test the application workload locally without exposing it to the LAN or internet:

```powershell
kubectl port-forward -n hybrid-lab service/hybrid-demo 8080:80
```

Then browse to `http://localhost:8080`.

## Chaos validation

Repeatable availability, pod-failure, CPU-saturation, and NetworkPolicy experiments are maintained in `../chaos`. Those scripts collect evidence while leaving the GitOps manifests as the source of desired state.

## Next stages

The read-only status API is the first public-demo backend. After its live data is verified, the frontend can consume `/api/status` through a same-origin Cloudflare route. Mutation endpoints will remain a separate phase with their own service account, stricter RBAC, experiment lock, cooldown, bounded durations, and abuse protection.
