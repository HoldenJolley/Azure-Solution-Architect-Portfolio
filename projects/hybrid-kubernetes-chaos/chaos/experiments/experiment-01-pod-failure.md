# Experiment 01 - Single-Pod Failure and Service Continuity

## Objective

Validate that the GitOps-managed `hybrid-demo` workload can tolerate the loss of one application pod, automatically restore the declared three-replica state, and continue serving traffic through the Kubernetes Service during recovery.

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

All three application replicas were scheduled on the single physical node. This experiment therefore validates pod-level resilience, not node-level resilience.

## Failure injection

A PowerShell chaos script selected one healthy `hybrid-demo` pod at random and deleted it with `kubectl delete pod --wait=false`.

Recorded experiment timestamp: 2026-10-26 20:24:06 -04:00.

Selected pod:

```text
hybrid-demo-59c9bcf8bb-6zs87
```

Pre-chaos state:

```text
desiredReplicas=3
readyReplicas=3
```

Immediately after deletion, the Deployment dropped to 2/3 Ready replicas. Kubernetes created a replacement pod automatically.

## Recovery result

The Deployment returned to its declared state of 3/3 Ready and 3/3 Available replicas in:

```text
6.89 seconds
```

Chaos-script result:

```text
RESULT=PASS recoverySeconds=6.89
```

Local recovery evidence:

```text
./evidence/pod-delete-20261026-202406.txt
```

A prior run produced a nearly identical 6.9-second recovery time, indicating consistent pod-level recovery behavior in this lab.

## Availability measurement

Availability was measured from inside Kubernetes using a short-lived curl probe pod calling the Service through cluster DNS:

```text
http://hybrid-demo.hybrid-lab.svc.cluster.local
```

Results:

| Metric | Result |
| --- | ---: |
| Requests observed | 109 |
| Successful requests | 109 |
| Failed requests | 0 |
| Observed availability | 100% |
| Pod recovery time | 6.89 s |

Local availability evidence:

```text
./evidence/availability-20261026-202400.csv
```

## Interpretation

The controlled loss of one application replica reduced ready capacity from 3/3 to 2/3, but the Service continued routing requests to healthy endpoints. Kubernetes restored the missing replica in 6.89 seconds, and no failed service requests were observed during the in-cluster measurement window.

The defensible conclusion from this experiment is:

> During a controlled single-pod failure, Kubernetes restored the workload to its three-replica desired state in 6.89 seconds while maintaining 100% observed service availability across 109 in-cluster requests.

This result demonstrates Kubernetes Deployment self-healing, Service endpoint resilience, and Flux-maintained desired state on the physical Azure Arc-connected cluster.

## Discarded measurement

An earlier availability run reported 56.82% availability using `kubectl port-forward service/hybrid-demo`. That result is not treated as application availability evidence.

`kubectl port-forward` selects a backend pod for the forwarding session. When that selected pod is deleted, the local forwarding connection can terminate even while the Kubernetes Service still has healthy endpoints. The test methodology was corrected by moving the availability probe inside the cluster and targeting the ClusterIP Service directly.

## Limitation and next experiment

All three replicas currently run on `k8s-edge-01`. A physical node failure would therefore remove every application replica simultaneously. Node-level resilience requires at least one additional Kubernetes worker node.

The next chaos tier should test degradation rather than complete pod deletion, such as CPU or memory pressure, network disruption, or another fault where Kubernetes must react to an unhealthy but still-running workload.
