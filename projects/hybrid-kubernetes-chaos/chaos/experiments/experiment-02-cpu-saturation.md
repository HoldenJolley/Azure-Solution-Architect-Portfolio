# Experiment 02 - Bounded CPU Saturation and Service Continuity

## Objective

Validate that the GitOps-managed `hybrid-demo` workload can tolerate sustained CPU pressure inside one application replica while keeping that pod alive and maintaining service availability through the Kubernetes Service.

Unlike Experiment 01, this test does not remove a pod. It creates a degraded-but-still-running condition inside one replica.

## Environment

- Physical host: `k8s-edge-01`
- Kubernetes: v1.37.1
- Container runtime: containerd
- CNI: Calico
- Azure integration: Azure Arc-enabled Kubernetes
- GitOps: Flux
- Namespace: `hybrid-lab`
- Deployment: `hybrid-demo`
- Desired replicas: 3
- Application container: `nginx`
- CPU limit per application container: `250m`

All three application replicas were scheduled on the same physical node. This experiment therefore validates pod-level workload behavior under CPU pressure, not node-level resilience.

## Failure injection

A PowerShell chaos script selected one healthy `hybrid-demo` pod at random and executed a CPU-bound shell loop inside the NGINX container for 30 seconds.

Recorded experiment timestamp: 2026-10-26 20:35:46 -04:00.

Selected pod:

```text
hybrid-demo-59c9bcf8bb-rgc8q
```

Pre-chaos state:

```text
readyReplicas=3
cpuLimit=250m
```

The injected busy loop remained bounded by an in-container timeout. The command ended after 30.73 seconds with exit code 143, which is the expected SIGTERM used by the timeout implementation to stop the workload at the configured duration.

## Workload result

After the stress interval, the selected pod remained healthy:

```text
podPhase=Running
ready=True
restartCount=0
elapsedSeconds=30.73
```

Chaos-script result:

```text
RESULT=PASS target pod remained Running and Ready after bounded CPU saturation.
```

Local stress evidence:

```text
./evidence/cpu-stress-20261026-203546.txt
```

## Availability measurement

Availability was measured from inside Kubernetes using the same short-lived curl probe used for Experiment 01. The probe called the Service through cluster DNS while the CPU stress was active:

```text
http://hybrid-demo.hybrid-lab.svc.cluster.local
```

Results:

| Metric | Result |
| --- | ---: |
| Requests observed | 110 |
| Successful requests | 110 |
| Failed requests | 0 |
| Observed availability | 100% |
| Stress duration | 30.73 s |
| Target pod restarts | 0 |

Local availability evidence:

```text
./evidence/availability-20261026-203540.csv
```

## Interpretation

One application replica was deliberately subjected to sustained CPU pressure while remaining part of the three-replica Service. The target pod stayed Running and Ready, did not restart, and all 110 observed in-cluster requests succeeded during the measurement window.

The defensible conclusion from this experiment is:

> During 30.73 seconds of bounded CPU saturation inside one `250m`-limited application replica, the target pod remained Running and Ready with zero restarts while the Kubernetes Service maintained 100% observed availability across 110 in-cluster requests.

This result demonstrates the value of workload resource limits and replicated service routing under a degraded-but-alive pod condition. It complements Experiment 01, which tested complete pod loss and automatic replacement.

## Test-harness correction

An initial run incorrectly reported failure because the script treated exit code 143 as unexpected. The stress process had actually run for the intended duration and was terminated by the timeout command using SIGTERM. The harness was corrected to accept exit code 143 only when the elapsed runtime confirms that the bounded stress interval completed, preventing an early termination from being misclassified as a pass.

## Limitations and next experiment

The workload is lightweight static NGINX content, so a single CPU-bound worker at the container's `250m` CPU limit may not meaningfully impair HTTP responsiveness. The experiment proves continuity under this specific resource-pressure condition; it does not prove resilience to more severe CPU starvation, memory exhaustion, network faults, or node loss.

A useful next step is network disruption or memory pressure, which can exercise readiness behavior and service endpoint removal more directly than this CPU-only test.
