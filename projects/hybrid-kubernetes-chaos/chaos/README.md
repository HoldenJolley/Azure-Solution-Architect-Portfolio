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

### Experiment 03 - single-pod network isolation

Documented at `experiments/experiment-03-network-isolation.md`.

The first recorded run showed 100% Service availability while a temporary deny-ingress NetworkPolicy selected one application pod. Because that run did not directly test the selected pod IP, it is retained as policy-injection/service-continuity evidence rather than conclusive endpoint-isolation evidence.

The current version of `isolate-one-pod.ps1` strengthens the experiment by creating an independent curl pod and asserting direct target-pod reachability before, during, and after policy application.

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

## Experiment 03 - single-pod network isolation

The third experiment uses a temporary Kubernetes `NetworkPolicy` to isolate one randomly selected application pod from normal pod-originated ingress traffic while leaving the pod process itself running.

Start the in-cluster Service availability probe:

```powershell
./availability-probe.ps1 -DurationSeconds 120
```

Once the availability probe pod is Running, execute the network-isolation experiment in another PowerShell window:

```powershell
./isolate-one-pod.ps1 -IsolationSeconds 30
```

The current `isolate-one-pod.ps1` performs two independent measurements:

1. **Direct endpoint validation.** It creates a temporary curl pod and calls the selected application's pod IP directly. A conclusive isolation run must observe `reachable-before -> unreachable-during -> reachable-after`.
2. **Service continuity.** `availability-probe.ps1` simultaneously calls the Kubernetes Service through cluster DNS so availability can be measured while the individual endpoint is isolated.

The isolation script:

1. verifies that multiple application replicas are Ready;
2. randomly selects one Ready `hybrid-demo` pod;
3. creates an independent direct-endpoint probe pod;
4. verifies the target pod IP is reachable before fault injection;
5. applies a temporary chaos-only label to the target pod;
6. creates a deny-ingress `NetworkPolicy` selecting only that pod;
7. verifies direct pod-IP connectivity from the independent probe is blocked;
8. holds the policy for the bounded isolation interval;
9. removes the NetworkPolicy and temporary label;
10. verifies direct pod-IP connectivity is restored;
11. verifies the target pod remains Running and Ready;
12. removes the temporary direct-endpoint probe pod in cleanup.

Expected direct-validation evidence for a conclusive run resembles:

```text
Direct-before reachable=True statusCode=200 exitCode=0
Direct-during reachable=False statusCode=000 exitCode=28
Direct-after reachable=True statusCode=200 exitCode=0
RESULT=PASS direct endpoint sequence was reachable-before, unreachable-during, reachable-after.
```

If the endpoint remains reachable while the policy is active, the script reports `RESULT=INCONCLUSIVE` rather than claiming that network isolation occurred.

## Experiment progression

The experiments cover three distinct failure modes:

- Experiment 01: complete loss of one application pod followed by Kubernetes self-healing.
- Experiment 02: a degraded-but-still-running pod under bounded CPU pressure.
- Experiment 03: selective network isolation of a still-running pod using NetworkPolicy, with direct endpoint validation and simultaneous Service availability measurement.

Experiments 01 and 02 maintained 100% observed in-cluster Service availability in their recorded runs. The initial Experiment 03 policy-injection run also maintained 100% availability, but the strengthened direct-endpoint version should be used before claiming that the selected endpoint was definitively isolated.

Node-level failure testing should wait until the cluster has an additional worker node because all current application replicas run on the same physical host.
