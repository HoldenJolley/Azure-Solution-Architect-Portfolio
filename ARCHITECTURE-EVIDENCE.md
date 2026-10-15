# Architecture Evidence Register

This document is the cross-project evidence index for the Azure Solution Architect portfolio. Its purpose is to distinguish **design intent**, **compiler validation**, **live Azure control-plane validation**, and **runtime/deployment evidence** so the portfolio does not overstate what has been proven.

## Evidence levels

| Level | Meaning | What it proves | What it does not prove |
|---|---|---|---|
| Design | Architecture documents, ADRs, diagrams, contracts, runbooks | The intended requirements, boundaries, decisions, and operating model are documented | That Azure accepts the configuration or that the workload works at runtime |
| Compiler | Bicep lint/build and parameter compilation | Templates are syntactically and structurally valid for the compiler | Subscription capacity, provider behavior, deployment success, or runtime behavior |
| Control plane | GitHub Actions authenticates to Azure with OIDC and ARM What-If evaluates the deployment | Azure can evaluate the proposed resource graph against the live subscription/control plane without creating resources | Resource creation, application behavior, failover, performance, or end-to-end correctness |
| Runtime | Resources are deployed and workload tests execute against them | Observed behavior of the deployed system | Future behavior outside the tested conditions |

The portfolio currently has **design, compiler, and control-plane evidence**. It does **not** yet claim runtime evidence for any of the three Azure workloads.

## Evidence matrix

### Cost-Optimized Portfolio Hosting

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Architecture | Documented | Requirements/constraints, cost model, security, operations, performance, ADRs, and known limitations are source-controlled | Revisit after the first production deployment and domain cutover |
| Bicep | Validated | Infrastructure lint/build and production parameter compilation are green | Re-run for every infrastructure change |
| Azure authentication | Validated | GitHub Actions authenticates to Azure through short-lived OIDC federation; no reusable Azure client secret is required | Separate the long-lived static-hosting identity from the broader portfolio bootstrap/validation identity if retained for production |
| ARM What-If | Validated | Live subscription-scope What-If resolves the intended footprint to one resource group and one Free-tier Azure Static Web App | Re-run immediately before deployment and after material template changes |
| Deployment | **Not executed** | Production resource creation remains manually gated | Create the resource group and Static Web App through the approved deployment path |
| Content runtime | **Not validated** | No public Azure-hosted runtime evidence yet | Verify site assets, navigation, security headers, TLS, redirects, 404 behavior, and custom domain after deployment |
| Recovery | Designed, not exercised | Git is the source of truth; recovery is revert + redeploy | Perform and record a controlled rollback/redeploy exercise after deployment |

### Distributed E-Commerce Platform

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Architecture | Documented | Requirements/constraints, data, networking, security, threat model, observability, reliability/DR, cost, CI/CD, ADRs, diagrams, testing guidance, and known limitations are source-controlled | Update decisions when application implementation or business requirements change |
| Bicep | Validated | Dev, test, and production Bicep/parameter validation is green | Re-run for every infrastructure change |
| Azure authentication | Validated | GitHub Actions authenticates through short-lived OIDC federation with no Azure client secret | Validate final least-privilege production deployment identity/scope before production use |
| ARM What-If | Validated for dev architecture | Live subscription-scope ARM What-If completes successfully and predicts 41 creates | Review What-If again before any deployment and for higher-cost production parameters |
| Identity-dependent RBAC | Partially resolvable by What-If | 14 role assignments are reported as unsupported because their resource IDs depend on managed-identity principal IDs created during deployment | Verify the resulting assignments after identities are actually created |
| Deployment | **Not executed** | Deployment job remains explicitly gated | Deploy only after cost/scope review if runtime evidence is desired |
| Application runtime | **Not validated** | Infrastructure package currently does not include the full commerce application binaries | Implement/deploy API and workers, then run end-to-end workflow tests |
| Reliability | Designed, not exercised | Failure behavior and recovery expectations are documented | Exercise Front Door origin failover, worker redelivery/idempotency, poison-message DLQ handling, payment failure/release behavior, inventory race behavior, and Cosmos regional failover |
| Messaging continuity | Known limitation | Current production reference uses one Service Bus namespace | Select and test a Service Bus regional-continuity design before claiming regional messaging RTO |

### Privacy-Preserving AI Age Assurance

| Evidence area | Current status | Evidence | Remaining validation |
|---|---|---|---|
| Architecture | Documented | Requirements/constraints, privacy/security contracts, threat model, networking, key management, model integration, observability, cost, reliability/DR, ADRs, diagrams, testing guidance, and known limitations are source-controlled | Revisit for customer model, jurisdiction, or high-availability requirements |
| Bicep | Validated | Foundation and workload Bicep lint/build cleanly and dev/test/prod parameter files compile | Re-run for every infrastructure change |
| Azure authentication | Validated | GitHub Actions authenticates through short-lived OIDC federation | Validate final least-privilege deployment identity/scope before production use |
| ARM What-If | Validated for dev foundation | Live dev foundation What-If resolves 24 planned creates | Re-run before deployment and validate workload stage after foundation prerequisites exist |
| Identity-dependent RBAC | Partially resolvable by What-If | Two foundation RBAC resources can remain unsupported because their names/targets depend on managed-identity principal IDs created during deployment | Verify assignments after identities exist |
| Managed Redis | Compiler validated for production profiles; omitted from deterministic dev cloud preflight | Live B0/B1 capacity checks failed for the current subscription/target regions, so dev What-If disables the session store | Confirm capacity/tier/region or explicitly review an alternative before deployment |
| Deployment | **Not executed** | What-If creates no resources | Deploy foundation, push customer-supplied gateway/inference images, deploy workloads, and approve the Front Door Private Link connection if runtime evidence is desired |
| Privacy invariant | Designed, not runtime proven | Architecture prohibits intentional image persistence and limits plaintext to client/inference memory | Test application code, logging, telemetry, crash paths, and storage to prove request bodies/image-derived artifacts do not persist |
| Availability / fail-closed behavior | Designed, not exercised | Key Vault, Redis, model health, replica, and regional failure behavior are documented | Run controlled dependency and replica failure tests after deployment |
| Model suitability / compliance | Outside infrastructure evidence | Platform defines the secure execution/integration boundary | Customer/product/legal teams must separately validate model accuracy, fairness, accessibility, liveness, and jurisdiction-specific compliance |

## Evidence that must not be inferred

Until runtime validation is completed, do **not** describe any portfolio workload as deployed, production-running, highly available in practice, performance-tested, or disaster-recovery-tested. A successful What-If proves that Azure evaluated the proposed resource changes; it does not prove that the resources were created or that the workload behaves correctly.

## Runtime evidence checklist for future deployments

When a workload is actually deployed, capture evidence in the project documentation rather than replacing the existing pre-deployment record:

1. deployment date, environment, region(s), and commit SHA;
2. successful deployment/run identifier;
3. resource inventory or deployment output with sensitive identifiers redacted where appropriate;
4. smoke-test and health-check results;
5. security and network-path checks;
6. failure/recovery exercises relevant to the project's NFRs;
7. observed performance/capacity data where a target exists;
8. rollback/recovery result;
9. known differences between the deployed environment and reference architecture;
10. updated statement of what remains unproven.

## Portfolio evidence principle

**Validated is not the same as deployed, and deployed is not the same as production proven.** The portfolio deliberately keeps those evidence levels separate.