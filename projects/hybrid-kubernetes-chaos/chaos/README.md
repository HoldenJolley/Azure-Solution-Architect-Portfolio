# Controlled Chaos Experiments

This directory contains repeatable chaos-engineering checks for the physical `k8s-edge-01` cluster.

## Recorded results

### Experiment 01 - single-pod failure

Documented at `experiments/experiment-01-pod-failure.md`.

Validated result:

- desired state before failure: 3/3 Ready replicas
- injected failure: one randomly selected application pod deleted
- recovery: 3/3 Ready and Available in 6.89 seconds
- in-cluster availability samples: 109
- successful requests: 109
- failed requests: 0
- observed service availability: 100%

A prior port-forward-based availability result was discarded as a measurement artifact and is documented in the experiment report.

### Experiment 02 - bounded CPU saturation

Documented at `experiments/experiment-02-cpu-saturation.md`.

Validated result:

- desired state before stress: 3 Ready replicas
- injected degradation: one CPU-bound worker inside a randomly selected application container
- target container CPU limit: 250m
- bounded stress duration: 30.73 seconds
- target pod after stress: Running and Ready
- target container restarts: 0
- in-cluster availability samples: 110
- successful requests: 110
- failed requests: 0
- observed service availability: 100%

The first CPU-stress run exposed a harness issue: BusyBox `timeout` surfaced the expected end of the bounded stress process as exit code 143 (SIGTERM). The script now accepts that code only when elapsed time confirms the requested stress duration completed.

### Experiment 03 - NetworkPolicy fault

Documented at `experiments/experiment-03-network-isolation.md`.

Recorded result:

- desired state before policy injection: 3 Ready replicas
- target pod remained Running and Ready with 0 restarts
- temporary deny-ingress NetworkPolicy hold interval: 30 seconds
- policy and temporary label removed cleanly
- in-cluster availability samples: 97
- successful requests: 97
- failed requests: 0
- observed service availability: 100%

The result proves service continuity during the policy change, but it is intentionally not presented as conclusive proof that the selected replica became unreachable. All workloads currently share one physical node, and this run did not directly probe the selected pod IP during the policy interval. A follow-up version should add direct pre/during/post reachability checks against the target pod while continuing to monitor Service availability.

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

The second experiment keeps the target pod alive and deliberately saturates one CPU worker inside its NGINX container. The workload currently has a `250m` CPU limit, so the busy loop is constrained by the container's cgroup rather than consuming an unrestricted CPU core.

Start the same in-cluster availability probe:

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

## Experiment 03 - single-pod NetworkPolicy fault

The third experiment applies a temporary Kubernetes `NetworkPolicy` to one randomly selected application pod while leaving the pod process itself running.

Start the in-cluster availability probe:

```powershell
./availability-probe.ps1 -DurationSeconds 120
```

Once the probe pod is Running, execute the policy experiment in another PowerShell window:

```powershell
./isolate-one-pod.ps1 -IsolationSeconds 30
```

`isolate-one-pod.ps1`:

1. verifies that multiple application replicas are Ready;
2. randomly selects one Ready `hybrid-demo` pod;
3. applies a temporary chaos-only label to that pod;
4. creates a deny-ingress `NetworkPolicy` selecting only that label;
5. holds the policy for a bounded period;
6. removes the NetworkPolicy and temporary label in a `finally` cleanup block;
7. verifies that the target pod is Running and Ready after cleanup;
8. writes timestamped evidence under `./evidence`.

The experiment result reports whether the policy fault was applied and cleaned up successfully. Application availability is evaluated separately from the availability-probe CSV.

## Experiment progression

The experiments now cover three distinct fault modes:

- Experiment 01: complete loss of one application pod followed by Kubernetes self-healing.
- Experiment 02: a degraded-but-still-running pod under bounded CPU pressure.
- Experiment 03: a temporary NetworkPolicy applied to one still-running replica, with service continuity observed throughout the recorded run.

All three recorded runs maintained 100% observed in-cluster Service availability. Experiment 03 requires one additional direct reachability assertion before it should be described as conclusive endpoint isolation.

Node-level failure testing should wait until the cluster has an additional worker node because all current application replicas run on the same physical host.
