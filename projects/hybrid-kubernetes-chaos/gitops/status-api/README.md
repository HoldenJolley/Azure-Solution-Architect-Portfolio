# Hybrid Kubernetes Status API

This service is the read-only backend for the public chaos-lab dashboard. It runs inside `hybrid-lab` and exposes a deliberately small status surface without any Kubernetes mutation permissions.

## Endpoints

- `GET /healthz` — process health only.
- `GET /api/status` — current Kubernetes, Flux, workload, pod, and in-cluster Service reachability state.

There are intentionally no `POST`, `PUT`, `PATCH`, or `DELETE` endpoints in this phase.

## Data sources

The API reads:

- the `hybrid-demo` Deployment;
- pods in `hybrid-lab` with `app.kubernetes.io/name=hybrid-demo`;
- optional pod metrics when the Metrics API is available;
- node `k8s-edge-01` and Kubernetes `/version`;
- Flux Kustomization `hybrid-gitops/hybrid-lab-gitops-hybrid-lab`;
- the application Service directly through `http://hybrid-demo.hybrid-lab.svc.cluster.local`.

The in-cluster Flux object name is generated from the Azure Arc Flux configuration name (`hybrid-lab-gitops`) and its named Kustomization (`hybrid-lab`), resulting in `hybrid-lab-gitops-hybrid-lab`.

Azure Arc is reported only as a configured architecture fact in this first API version. The endpoint does not call Azure APIs and therefore does not claim that the Arc control plane is live based on this response alone.

## RBAC boundary

The service account can read the application Deployment and pods, the single physical node, Kubernetes version, and the named Flux Kustomization. It has no permissions to create, update, patch, delete, exec into, or scale Kubernetes resources.

Useful proof checks:

```powershell
kubectl auth can-i get deployment/hybrid-demo -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-status-api
kubectl auth can-i list pods -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-status-api
kubectl auth can-i get kustomization/hybrid-lab-gitops-hybrid-lab -n hybrid-gitops --api-group=kustomize.toolkit.fluxcd.io --as=system:serviceaccount:hybrid-lab:hybrid-status-api
kubectl auth can-i delete pods -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-status-api
kubectl auth can-i patch deployment/hybrid-demo -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-status-api
```

The first three should return `yes`; the mutation checks should return `no`.

## Local validation

After Flux reconciles:

```powershell
kubectl get deployment,service,pod -n hybrid-lab -l app.kubernetes.io/name=hybrid-status-api
kubectl port-forward -n hybrid-lab service/hybrid-status-api 8081:80
```

In another PowerShell window:

```powershell
Invoke-RestMethod http://127.0.0.1:8081/healthz

$status = Invoke-RestMethod http://127.0.0.1:8081/api/status
$status | ConvertTo-Json -Depth 10
```

The dashboard will eventually consume the same `/api/status` path through `chaos.holdenjolley.com`, keeping browser traffic same-origin and leaving the Kubernetes API private.
