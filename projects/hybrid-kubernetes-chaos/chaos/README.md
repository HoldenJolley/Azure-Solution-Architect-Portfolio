# Controlled Chaos Experiments

This directory contains the first repeatable chaos-engineering checks for the physical `k8s-edge-01` cluster.

The initial experiment deliberately stays simple: measure availability through the real Kubernetes `hybrid-demo` Service, delete one randomly selected application pod, and verify that the Deployment restores the desired replica count.

## Recorded results

Experiment 01 is documented at `experiments/experiment-01-pod-failure.md`.

Validated result:

- desired state before failure: 3/3 Ready replicas
- injected failure: one randomly selected application pod deleted
- recovery: 3/3 Ready and Available in 6.89 seconds
- in-cluster availability samples: 109
- successful requests: 109
- failed requests: 0
- observed service availability: 100%

A prior port-forward-based availability result was discarded as a measurement artifact and is documented in the experiment report.

## Why the availability probe runs inside Kubernetes

`kubectl port-forward service/...` is useful for interactive access, but it is not a valid service-availability measurement during pod deletion. `kubectl port-forward` selects a backend pod; if that selected pod terminates, the forwarding session ends even when the Kubernetes Service still has other healthy endpoints.

For chaos measurement, `availability-probe.ps1` therefore creates a short-lived curl pod inside `hybrid-lab`. That probe calls `http://hybrid-demo.hybrid-lab.svc.cluster.local` through normal Kubernetes service discovery and service routing, then downloads the resulting CSV evidence to the Windows management machine.

## Prerequisites

- Azure Arc Cluster Connect proxy is running if `kubectl` is using the Arc proxy kubeconfig.
- `kubectl get pods -n hybrid-lab` shows three healthy `hybrid-demo` replicas.
- The portfolio repository is cloned locally on the Windows management machine.

## 1. Start the availability probe

In PowerShell window 1, from this directory:

```powershell
./availability-probe.ps1 -DurationSeconds 120
```

The probe creates an ephemeral `curlimages/curl` pod inside the cluster, requests the `hybrid-demo` Service once per second, and writes timestamped CSV evidence under `./evidence`. The script removes the probe pod after collecting the logs.

## 2. Inject a controlled failure

While the availability probe is running, use PowerShell window 2:

```powershell
./delete-random-pod.ps1
```

The script:

1. verifies the Deployment's desired and ready replica counts;
2. randomly selects one running `hybrid-demo` pod;
3. deletes it without waiting for termination;
4. polls the Deployment until the desired number of replicas are Ready again;
5. records measured recovery time under `./evidence`.

## Expected result

Kubernetes should create a replacement pod automatically and return the Deployment to its GitOps-declared three-replica state. Because the availability probe reaches the actual ClusterIP Service rather than a port-forwarded individual pod, this test measures whether healthy service endpoints continued serving requests during the failure.

This establishes a measurable baseline before adding a dedicated chaos platform and more disruptive scenarios such as network loss, CPU/memory stress, node failure, and dependency faults.
