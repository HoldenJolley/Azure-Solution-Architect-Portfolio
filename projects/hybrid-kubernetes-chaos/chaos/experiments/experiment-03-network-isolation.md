# Experiment 03 - Single-Pod NetworkPolicy Fault

## Objective

Evaluate Kubernetes Service continuity while a temporary `NetworkPolicy` makes one `hybrid-demo` replica directly unreachable from another pod, without terminating or restarting the application process.

## Environment

- Physical host: `k8s-edge-01`
- Namespace: `hybrid-lab`
- Deployment: `hybrid-demo`
- Desired replicas: 3
- CNI: Calico
- All application replicas and test probes run on the same physical Kubernetes node.

This experiment validates pod-level network isolation and Service continuity. It does not validate node-level resilience because the cluster currently has only one physical node.

## Fault injection

Recorded experiment timestamp: 2026-10-26 20:49:48 -04:00.

Selected pod:

```text
hybrid-demo-59c9bcf8bb-l5j8v
```

Selected pod IP:

```text
10.244.199.101
```

Pre-chaos state:

```text
readyReplicas=3
```

The experiment created an independent curl probe pod and first verified that the selected application pod IP was directly reachable.

Pre-fault direct validation:

```text
Direct-before reachable=True statusCode=200 exitCode=0
```

The script then applied a temporary chaos-only label to the selected application pod and created a deny-ingress `NetworkPolicy` selecting only that pod.

Policy:

```text
chaos-deny-ingress-20261026-204948
```

## Direct endpoint isolation proof

After the policy propagated, the independent probe attempted to reach the selected pod IP directly.

During-fault result:

```text
Direct-during reachable=False statusCode=000 exitCode=28
```

This confirms that the selected replica became unreachable from the independent in-cluster probe while the NetworkPolicy was active.

During the same interval, Kubernetes continued reporting the selected pod as:

```text
podPhase=Running
ready=True
restartCount=0
```

The policy was held for 30 seconds and then removed. The temporary chaos label was also removed.

After cleanup, direct pod-IP connectivity was restored:

```text
Direct-after reachable=True statusCode=200 exitCode=0
```

The selected pod remained Running and Ready with zero restarts.

Chaos-script result:

```text
RESULT=PASS direct endpoint sequence was reachable-before, unreachable-during, reachable-after.
```

Local fault-injection evidence:

```text
./evidence/network-isolation-20261026-204948.txt
```

## Service availability measurement

A separate in-cluster availability probe began at approximately 20:49:42, before the network-isolation experiment began at 20:49:48, and continued through the full fault window.

The probe called the Kubernetes Service through cluster DNS:

```text
http://hybrid-demo.hybrid-lab.svc.cluster.local
```

Evidence file:

```text
./evidence/availability-20261026-204942.csv
```

Results:

| Metric | Result |
| --- | ---: |
| Requests observed | 100 |
| Successful requests | 100 |
| Failed requests | 0 |
| Observed Service availability | 100% |
| Network-isolation hold interval | 30 s |

## Interpretation

The experiment proved two facts independently during the same test window:

1. The selected application replica changed from directly reachable to directly unreachable while the NetworkPolicy was active, then became reachable again after cleanup.
2. The `hybrid-demo` Kubernetes Service returned successful responses for all 100 observed requests during the broader availability window.

The defensible conclusion is:

> During a controlled 30-second NetworkPolicy fault, one application replica was proven unreachable from an independent in-cluster pod while remaining Running and Kubernetes Ready. Direct connectivity recovered after policy removal, and the Kubernetes Service maintained 100% observed availability across 100 in-cluster requests during the matched test window.

An important architectural observation is that `Ready=True` did not guarantee reachability from another pod in this failure mode. The kubelet continued considering the target healthy while an independent workload could not reach its pod IP. This illustrates why application health validation should include realistic client-path measurements in addition to local readiness probes.

The experiment intentionally does not claim a specific dataplane mechanism for the 100% Service result. The evidence shows that direct pod-IP traffic to the selected replica was blocked while Service requests continued succeeding; determining exactly how Service routing behaved during each request would require additional endpoint, conntrack, or packet-level instrumentation.

## Limitation and next tier

All application replicas currently run on `k8s-edge-01`. A failure of that physical node would still remove the entire workload. Genuine node-failure resilience requires at least one additional Kubernetes worker node.

The next chaos tier can therefore focus on another pod-level failure mode, such as memory pressure or dependency failure, while node-failure testing should wait until a second worker is available.
