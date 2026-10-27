# Architecture Evidence Register

This document is the cross-project evidence index for the Azure Solution Architect portfolio. Its purpose is to distinguish **design intent**, **compiler validation**, **live Azure control-plane validation**, and **runtime/deployment evidence** so the portfolio does not overstate what has been proven.

## Evidence levels

| Level | Meaning | What it proves | What it does not prove |
|---|---|---|---|
| Design | Architecture documents, ADRs, diagrams, contracts, runbooks, experiment plans | The intended requirements, boundaries, decisions, and operating model are documented | That Azure or Kubernetes accepts the configuration or that the workload works at runtime |
| Compiler / manifest | Bicep lint/build, parameter compilation, or Kubernetes manifest validation | Templates/manifests are structurally valid for their tooling | Subscription capacity, deployment success, reconciliation success, or runtime behavior |
| Control plane | Azure OIDC + ARM What-If, Azure Arc registration, or GitOps control-plane reconciliation | The live management/control plane can evaluate or manage the intended resource/workload state | End-user behavior, physical resilience, performance, or every data-plane path |
| Runtime | Resources/workloads are deployed and tests execute against them | Observed behavior of the deployed system under the tested conditions | Future behavior outside the tested conditions or untested failure domains |

The portfolio now contains all four evidence levels across different projects. Evidence remains project-specific: one project's runtime proof is never generalized to another project.

## Evidence matrix

### Cost-Optimized Portfolio Hosting

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Architecture | Documented | Requirements/constraints, cost model, security, operations, performance, ADRs, and known limitations are source-controlled | Revisit when traffic, availability needs, or business criticality changes |
| Bicep | Validated | Infrastructure lint/build and production parameter compilation are green | Re-run for every infrastructure change |
| Azure authentication | Validated | GitHub Actions authenticates to Azure through short-lived OIDC federation; no reusable Azure client secret is required | Maintain least-privilege production identity/scope |
| ARM What-If | Validated | Live subscription-scope What-If evaluates the intended Static Web Apps footprint | Re-run before material infrastructure changes |
| Deployment | **Executed** | Azure Static Web Apps hosts the live portfolio origin | Continue validating after deployment changes |
| Content runtime | **Validated for current site behavior** | Public site delivery, custom-domain routing, and portfolio access paths have been exercised | Re-test after material routing/security changes |
| Recovery | Partially exercised operationally | Git remains the source of truth and the deployment path is reproducible | Record a deliberate rollback/redeploy exercise if stronger recovery evidence is needed |

### Distributed E-Commerce Platform

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Architecture | Documented | Requirements/constraints, data, networking, security, threat model, observability, reliability/DR, cost, CI/CD, ADRs, diagrams, testing guidance, and known limitations are source-controlled | Update decisions when application implementation or business requirements change |
| Bicep | Validated | Dev, test, and production Bicep/parameter validation is green | Re-run for every infrastructure change |
| Azure authentication | Validated | GitHub Actions authenticates through short-lived OIDC federation with no Azure client secret | Validate final least-privilege production deployment identity/scope before production use |
| ARM What-If | Validated for dev architecture | Live subscription-scope ARM What-If completes successfully | Review What-If again before any deployment and for higher-cost production parameters |
| Identity-dependent RBAC | Partially resolvable by What-If | Some role assignments depend on principal IDs created during deployment | Verify resulting assignments after identities are actually created |
| Deployment | **Not retained as a running environment** | Guarded deployment validation can be performed without leaving the architecture running continuously | Deploy only after cost/scope review when additional runtime evidence is desired |
| Application runtime | **Not validated** | Infrastructure package does not represent a complete production commerce application | Implement/deploy API and workers, then run end-to-end workflow tests |
| Reliability | Designed, not exercised end-to-end | Failure behavior and recovery expectations are documented | Exercise Front Door origin failover, worker redelivery/idempotency, DLQ handling, payment failure/release behavior, inventory races, and Cosmos regional failover |
| Messaging continuity | Known limitation | Current production reference uses one Service Bus namespace | Select and test a Service Bus regional-continuity design before claiming regional messaging RTO |

### Privacy-Preserving AI Age Assurance

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Architecture | Documented | Requirements/constraints, privacy/security contracts, threat model, networking, key management, model integration, observability, cost, reliability/DR, ADRs, diagrams, testing guidance, and known limitations are source-controlled | Revisit for customer model, jurisdiction, or high-availability requirements |
| Bicep | Validated | Foundation and workload Bicep lint/build cleanly and dev/test/prod parameter files compile | Re-run for every infrastructure change |
| Azure authentication | Validated | GitHub Actions authenticates through short-lived OIDC federation | Validate final least-privilege deployment identity/scope before production use |
| ARM What-If | Validated for dev foundation | Live dev foundation What-If evaluates the intended resource graph | Re-run before deployment and validate workload stage after foundation prerequisites exist |
| Identity-dependent RBAC | Partially resolvable by What-If | Some RBAC resources depend on managed-identity principal IDs created during deployment | Verify assignments after identities exist |
| Managed Redis | Compiler validated for production profiles; omitted from deterministic dev cloud preflight | Live capacity checks constrained the deterministic dev preflight | Confirm capacity/tier/region or explicitly review an alternative before deployment |
| Deployment | **Not retained as a running environment** | Current evidence is design/compiler/control-plane focused | Deploy foundation and workloads only when runtime privacy/model evidence is desired |
| Privacy invariant | Designed, not runtime proven | Architecture prohibits intentional image persistence and limits plaintext to client/inference memory | Test code, logging, telemetry, crash paths, and storage to prove request bodies/image-derived artifacts do not persist |
| Availability / fail-closed behavior | Designed, not exercised | Key Vault, anti-replay state, model health, replica, and regional failure behavior are documented | Run controlled dependency and replica failure tests after deployment |
| Model suitability / compliance | Outside infrastructure evidence | Platform defines the secure execution/integration boundary | Customer/product/legal teams must separately validate model accuracy, fairness, accessibility, liveness, and jurisdiction-specific compliance |

### Hybrid Kubernetes Chaos Lab

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Physical cluster | **Running** | Ubuntu Server / kubeadm Kubernetes v1.37.1 on `k8s-edge-01`, containerd runtime, Calico CNI | Add another physical worker before node-resilience testing |
| Azure hybrid management | **Validated** | Cluster registered as Azure Arc-enabled Kubernetes in `rg-k8s-hybrid-lab`; Cluster Connect used successfully | Keep Arc management-path behavior separate from application availability claims |
| GitOps | **Validated at runtime** | Flux configuration tracks the GitHub repository; a Git change from 2 to 3 replicas reconciled automatically without manual `kubectl apply` | Add further policy/configuration changes as useful evidence |
| Service baseline | **Running** | Three `hybrid-demo` NGINX replicas behind a ClusterIP Service with probes and resource limits | Current replicas share one physical node |
| Pod-failure resilience | **Runtime validated** | Controlled deletion reduced Ready replicas from 3/3 to 2/3 and Kubernetes restored 3/3 in **6.89 seconds** | Repeat over longer series if statistical confidence is needed |
| Availability during pod deletion | **Runtime validated** | In-cluster Service probe observed **109/109 successful requests (100%)** during the matched experiment | Result applies to the observed test window, not a universal availability guarantee |
| CPU saturation | **Runtime validated** | One replica saturated for **30.73 seconds** at a **250m** CPU limit, remained Running/Ready with zero restarts; **110/110 Service requests succeeded** | Add latency/load-specific experiments if performance behavior becomes a target |
| Network isolation | **Runtime validated** | Independent pod observed target endpoint **reachable → unreachable → reachable** around a 30-second deny-ingress NetworkPolicy; target pod stayed Ready with zero restarts | Explore cross-node behavior after a second worker exists |
| Availability during network isolation | **Runtime validated** | Matched in-cluster Service probe observed **100/100 successful requests (100%)** | Do not infer every kube-proxy/Calico/conntrack scenario from one run |
| Measurement methodology | **Validated and corrected** | Availability probe runs inside Kubernetes and targets the Service DNS name; an earlier 56.82% port-forward result was discarded because it measured tunnel survivability instead of Service availability | Continue separating management-path failures from workload-path failures |
| Node-level resilience | **Not validated / not claimable** | All application replicas run on the single physical node `k8s-edge-01` | Add at least one additional worker, spread replicas, then run controlled node-failure testing |

## Evidence that must not be inferred

Do **not** generalize evidence beyond the tested boundary:

- A successful ARM What-If proves that Azure evaluated proposed changes; it does not prove the workload was created or works correctly.
- A live Static Web App proves the portfolio hosting path, not the runtime behavior of the other Azure reference architectures.
- The hybrid Kubernetes experiments prove observed pod/service behavior under specific controlled faults; they do not prove physical node high availability, multi-node failover, universal performance, or every network-failure mode.
- A Kubernetes pod reporting `Ready=True` does not prove that every independent workload can reach that pod. Experiment 03 directly demonstrated this distinction during NetworkPolicy isolation.

## Runtime evidence checklist for future deployments

When a workload is actually deployed or a new failure domain is tested, capture evidence in the project documentation rather than replacing the existing pre-deployment record:

1. deployment/test date, environment, region/node(s), and commit SHA;
2. successful deployment/run identifier;
3. resource or workload inventory with sensitive identifiers redacted where appropriate;
4. smoke-test and health-check results;
5. security and network-path checks;
6. failure/recovery exercises relevant to the project's NFRs;
7. observed performance/capacity data where a target exists;
8. rollback/recovery result;
9. known differences between the deployed environment and reference architecture;
10. updated statement of what remains unproven.

## Portfolio evidence principle

**Validated is not the same as deployed, and deployed is not the same as production proven.** Runtime evidence is reported only for the conditions actually exercised, and known limitations remain part of the architecture rather than being hidden after a successful test.
