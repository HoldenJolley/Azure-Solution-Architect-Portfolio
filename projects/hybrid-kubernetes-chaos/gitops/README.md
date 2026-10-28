# Hybrid Kubernetes GitOps

This directory is the reconciliation target for the physical `k8s-edge-01` Kubernetes cluster connected to Azure through Azure Arc.

## Current workload

The desired state remains intentionally small and inexpensive:

- `hybrid-lab` namespace
- three-replica NGINX `hybrid-demo` Deployment
- dashboard content generated from `../demo/index.html` and `../demo/live-status.js`
- internal `hybrid-demo` ClusterIP Service
- readiness/liveness probes and small CPU/memory limits
- one-replica read-only `hybrid-status-api` for the interactive dashboard
- one-replica `cloudflared` connector for outbound-only public access
- Metrics Server installed by Flux HelmRelease for live pod CPU and memory telemetry

The three application replicas provide enough redundancy for controlled pod-level failure testing while keeping the footprint tiny on the single-node lab. The status API is separate from the application workload so dashboard observation does not require exposing the Kubernetes API itself.

## Read-only status API

`status-api/` contains the read-only backend for `chaos.holdenjolley.com`.

It exposes only:

- `GET /healthz`
- `GET /api/status`

The API reads the `hybrid-demo` Deployment and pods, node `k8s-edge-01`, Kubernetes version, Flux Kustomization status, pod metrics when the Metrics API is available, and direct Service reachability. Its service account has no Kubernetes mutation permissions.

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

## Metrics Server

`metrics-server.yaml` declares the official Metrics Server Helm repository and pins chart `3.14.0` (Metrics Server `v0.9.0`). Flux installs the release into `kube-system` while the HelmRepository and HelmRelease desired state remain in `hybrid-lab`.

The lab currently passes `--kubelet-insecure-tls` because this kubeadm lab uses kubelet serving certificates that are not being treated as a production PKI trust path. This is an explicit lab-only tradeoff, not a production recommendation. A future hardening step is to issue and validate kubelet serving certificates against a trusted CA and remove this flag.

Validation:

```powershell
kubectl get helmrepository,helmrelease -n hybrid-lab
kubectl get deployment metrics-server -n kube-system
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top node
kubectl top pods -n hybrid-lab
```

Once the Metrics API responds, `/api/status` automatically begins returning real `cpu` and `memory` values for the `hybrid-demo` pods; no status API mutation permissions are added.

## Cloudflare Tunnel

`cloudflared.yaml` runs the outbound-only Cloudflare connector without a Kubernetes API token. The tunnel credential is intentionally excluded from Git and supplied as the namespace-scoped Secret `cloudflared-tunnel-token`.

The public dashboard and read-only API are routed through `chaos.holdenjolley.com`; no inbound router port is required on the physical lab network.

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

With public read-only telemetry and resource metrics in place, the next phase is a separate chaos-controller service with its own narrowly scoped service account. The first public mutation will be bounded single-pod deletion, followed by additional experiments only after lock, cooldown, automatic cleanup, rate limiting, and abuse protections are proven.
