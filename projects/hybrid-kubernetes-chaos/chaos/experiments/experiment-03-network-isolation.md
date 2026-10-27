# Experiment 03 - Single-Pod NetworkPolicy Fault

## Objective

Evaluate service behavior while a temporary Kubernetes `NetworkPolicy` targets one `hybrid-demo` replica for ingress isolation, without terminating or restarting the application process.

## Environment

- Physical host: `k8s-edge-01`
- Namespace: `hybrid-lab`
- Deployment: `hybrid-demo`
- Desired replicas: 3
- CNI: Calico
- All application replicas and the availability probe run on the same physical Kubernetes node.

This topology is important when interpreting the result: the experiment verifies that the policy was created, selected the intended pod, and was removed cleanly, but the recorded service-level result alone does not prove that traffic to the selected pod was actually dropped by the dataplane.

## Fault injection

Recorded experiment timestamp: 2026-10-26 20:41:40 -04:00.

Selected pod:

```text
hybrid-demo-59c9bcf8bb-c7nhq
```

Selected pod IP:

```text
10.244.199.103
```

Pre-chaos state:

```text
readyReplicas=3
```

The script applied a temporary label to the selected pod and created a deny-ingress `NetworkPolicy` selecting only that label.

Policy:

```text
chaos-deny-ingress-20261026-204140
```

The policy remained in place for 30 seconds and was then deleted. The temporary pod label was also removed.

## Pod health during the fault

During the policy interval, Kubernetes reported:

```text
podPhase=Running
ready=True
restartCount=0
```

After cleanup, the target pod remained Running and Ready with zero restarts.

Chaos-script result:

```text
RESULT=PASS network isolation was injected and removed; inspect availability evidence for service impact.
```

Local fault-injection evidence:

```text
./evidence/network-isolation-20261026-204140.txt
```

## Availability measurement

The in-cluster availability probe began at approximately 20:41:34, immediately before the network-policy experiment began at 20:41:40.

Evidence file:

```text
./evidence/availability-20261026-204134.csv
```

Results:

| Metric | Result |
| --- | ---: |
| Requests observed | 97 |
| Successful requests | 97 |
| Failed requests | 0 |
| Observed service availability | 100% |
| Policy hold interval | 30 s |

## Interpretation

No failed requests were observed through the `hybrid-demo` Kubernetes Service while the temporary policy was present. The targeted pod also remained Running and Ready throughout the experiment.

The defensible conclusion is therefore:

> A temporary deny-ingress NetworkPolicy was applied to one selected application replica for 30 seconds and removed cleanly, while the Service maintained 100% observed availability across 97 in-cluster requests and all replicas remained Running and Ready.

This result demonstrates service continuity during the policy change, but it should not yet be described as proof that one replica became unreachable. Because all workloads currently share the same physical node, and because the experiment did not directly test the selected pod IP from an independent probe while the policy was active, the service-level result cannot distinguish between several possibilities: the policy successfully blocked the selected endpoint and traffic continued through the other replicas, the selected endpoint was not chosen during the observation window, or the same-node/CNI dataplane path remained reachable.

## Follow-up validation

A stronger version of this experiment should add a direct reachability assertion during the policy interval:

1. start an independent probe pod;
2. target the selected pod IP directly rather than the Service;
3. verify that direct connectivity succeeds before policy creation;
4. verify that direct connectivity fails while the policy is active;
5. verify that direct connectivity succeeds again after cleanup;
6. simultaneously continue measuring Service availability.

That would separate two questions cleanly:

- Was the selected replica actually isolated?
- Did the Kubernetes Service remain available despite that isolation?

Until that direct assertion is added, the current run is retained as a valid policy-injection/service-continuity result, not as conclusive evidence of endpoint isolation.
