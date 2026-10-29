# Hybrid Chaos Controller

This package is the mutation boundary for the public Hybrid Kubernetes Chaos Lab. It is intentionally separate from the read-only status API.

## Current scope

Only one mutation is implemented:

- `POST /api/chaos/delete-pod`

The controller will only proceed when the `hybrid-demo` Deployment in `hybrid-lab` is healthy at its three-replica desired state. It selects one Ready workload pod, deletes it, and observes the Deployment until the healthy desired state is restored or the recovery deadline expires.

The controller also exposes:

- `GET /healthz`
- `GET /api/chaos/status`

## Guardrails

- one controller replica
- one experiment at a time
- pre-created Kubernetes Lease `hybrid-chaos-lock` for persistent lock/state
- 90-second cooldown after completion
- 45-second recovery deadline
- baseline must be 3/3 Ready and Available
- target must match the `hybrid-demo-*` workload naming pattern and workload label selector
- no shell, exec, patch, scale, node, Secret, ConfigMap, or cluster-wide permissions
- controller Service is ClusterIP only and is not routed through Cloudflare yet

The ServiceAccount can read the named `hybrid-demo` Deployment, list/get/delete pods in `hybrid-lab`, and get/update only the named `hybrid-chaos-lock` Lease. Kubernetes RBAC cannot restrict pod deletion by label, so the application also performs a strict label/name/baseline check before issuing a delete. This limitation is documented rather than hidden.

## Private validation

After Flux reconciles:

```powershell
kubectl get deployment,service,pod -n hybrid-lab -l app.kubernetes.io/name=hybrid-chaos-controller
kubectl get lease hybrid-chaos-lock -n hybrid-lab
```

RBAC proof:

```powershell
kubectl auth can-i delete pods -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-chaos-controller
kubectl auth can-i patch deployments -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-chaos-controller
kubectl auth can-i create pods -n hybrid-lab --as=system:serviceaccount:hybrid-lab:hybrid-chaos-controller
kubectl auth can-i update lease/hybrid-chaos-lock -n hybrid-lab --api-group=coordination.k8s.io --as=system:serviceaccount:hybrid-lab:hybrid-chaos-controller
```

Expected results are `yes`, `no`, `no`, `yes`.

Port-forward the internal Service for validation:

```powershell
kubectl port-forward -n hybrid-lab service/hybrid-chaos-controller 8082:80
```

Then from another PowerShell window:

```powershell
Invoke-RestMethod http://127.0.0.1:8082/healthz
Invoke-RestMethod http://127.0.0.1:8082/api/chaos/status | ConvertTo-Json -Depth 8
```

When ready to perform the controlled test locally:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8082/api/chaos/delete-pod | ConvertTo-Json -Depth 8
```

Watch recovery separately:

```powershell
kubectl get pods -n hybrid-lab -l app.kubernetes.io/name=hybrid-demo -w
```

Do not add a public Cloudflare route for the mutation endpoint until edge abuse protections and request authorization are in place.
