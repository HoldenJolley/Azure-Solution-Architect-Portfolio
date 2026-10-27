# Controlled Chaos Experiments

This directory contains repeatable chaos-engineering checks for the physical `k8s-edge-01` cluster.

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

## Experiment 01 - pod failure

Start the availability probe in PowerShell window 1:

```powershell
./availability-probe.ps1 -DurationSeconds 120
```

While the probe is running, use PowerShell window 2:

```powershell
./delete-random-pod.ps1
```

The failure script deletes one randomly selected application pod and measures how long the Deployment takes to restore its desired Ready replica count.

## Experiment 02 - bounded CPU saturation

The second experiment keeps the target pod alive and deliberately saturates one CPU worker inside its NGINX container. The workload currently has a `250m` CPU limit, so the busy loop should be throttled by the container's cgroup rather than consuming an unrestricted CPU core.

First pull the latest scripts, then start the same in-cluster availability probe:

```powershell
./availability-probe.ps1 -DurationSeconds 120
```

While the probe is running, execute the bounded CPU experiment in another PowerShell window:

```powershell
./stress-one-pod.ps1 -StressSeconds 30
```

`stress-one-pod.ps1`:

1. verifies that multiple application replicas are Ready;
2. randomly selects one Ready `hybrid-demo` pod;
3. records the pod, node, and configured CPU limit;
4. runs one CPU-bound BusyBox shell loop for 30 seconds using `timeout`;
5. verifies that the target pod remains Running and Ready afterward;
6. saves timestamped evidence under `./evidence`.

The 5-120 second guardrail and in-container `timeout` keep this experiment bounded even if the management session is interrupted.

### What to compare

For Experiment 02, compare the new availability CSV with Experiment 01. Useful signals are:

- request success rate during CPU saturation;
- average latency during the observation window;
- whether readiness or liveness fails;
- whether the container restarts;
- whether the other replicas preserve service availability.

This establishes a progression from explicit pod failure to degraded-but-still-running behavior before moving to network disruption, memory pressure, node failure, or a dedicated chaos platform.
