# Controlled Chaos Experiments

This directory contains the first repeatable chaos-engineering checks for the physical `k8s-edge-01` cluster.

The initial experiment deliberately stays simple: measure availability through the `hybrid-demo` service, delete one randomly selected application pod, and verify that the Kubernetes Deployment restores the desired replica count.

## Prerequisites

- Azure Arc Cluster Connect proxy is running if `kubectl` is using the Arc proxy kubeconfig.
- `kubectl get pods -n hybrid-lab` shows three healthy `hybrid-demo` replicas.
- The portfolio repository is cloned locally on the Windows management machine.

## 1. Start a local service tunnel

In PowerShell window 1:

```powershell
kubectl port-forward -n hybrid-lab service/hybrid-demo 8080:80
```

Leave this session running.

## 2. Start the availability probe

In PowerShell window 2, from this directory:

```powershell
./availability-probe.ps1 -DurationSeconds 120
```

The probe requests `http://localhost:8080` once per second and writes timestamped CSV evidence under `./evidence`.

## 3. Inject a controlled failure

While the availability probe is running, use PowerShell window 3:

```powershell
./delete-random-pod.ps1
```

The script:

1. verifies that at least two application replicas are healthy;
2. randomly selects one running `hybrid-demo` pod;
3. deletes it without waiting for termination;
4. waits for the Deployment to return to a healthy rollout state;
5. records recovery evidence under `./evidence`.

## Expected result

Kubernetes should create a replacement pod automatically and return the Deployment to its GitOps-declared three-replica state. Because the Service continues routing to healthy endpoints, the availability probe should normally show little or no user-visible outage during a single-pod failure.

This establishes a measurable baseline before adding a dedicated chaos platform and more disruptive scenarios such as network loss, CPU/memory stress, node failure, and dependency faults.
