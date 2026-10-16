# Non-Functional Requirements Matrix

This matrix ties the e-commerce architecture to the quality attributes it is intended to satisfy. It separates **design response** from **current evidence** so architectural intent is not mistaken for runtime proof.

| Quality attribute | Requirement / constraint | Design response | Current evidence | Remaining validation |
|---|---|---|---|---|
| Availability | Customer-facing checkout APIs should continue through a single regional application-origin failure in the production reference profile | Azure Front Door routes across primary/secondary App Service origins; stateless compute is deployed per region | Architecture and Bicep are documented/compiler validated; dev ARM What-If is successful | Deploy two-region profile and exercise Front Door origin failure/routing |
| Data durability / continuity | Operational commerce state must survive a regional Cosmos write-region failure with business-defined RPO/RTO | Cosmos DB is multi-region in the production profile with one authoritative write region and automatic failover | Architecture and parameters are compiler validated | Deploy, exercise Cosmos failover, measure recovery, and record observed RPO/RTO |
| Messaging continuity | Async order processing must have explicit regional-failure behavior | Current baseline uses one Service Bus namespace and explicitly treats regional messaging continuity as a separate design problem | Limitation is documented rather than hidden behind the multi-region label | Select, implement, and test a Service Bus continuity design before claiming messaging regional RTO |
| Consistency | Inventory must not be oversold under normal retries/concurrency | Inventory reservation is an explicit consistency boundary; single authoritative Cosmos write ownership; idempotent consumers expected | Data/ADR design is documented | Implement application logic and run concurrent inventory race tests plus retry/redelivery tests |
| Responsiveness | Checkout should not wait on every downstream fulfillment dependency | API accepts synchronous critical work, then Service Bus decouples payment/shipping/analytics processing | Architecture documented | Implement API/workers and measure request latency under representative load |
| Scalability | API and workers should scale independently when workload signals justify it | Separate App Service applications/plans support independent scale; async queues isolate bursts | Platform structure is modeled | Add autoscale only after real CPU/request/backlog signals are established and test scale behavior |
| Security | Minimize exposed origins and reusable secrets | Front Door + WAF is intended ingress; managed identities/RBAC; prod private endpoints/private DNS; data-service local/key auth disabled | Bicep/parameters and control-plane preflight validated | Deploy and verify access restrictions, identity permissions, private paths, WAF behavior, and secretless application access |
| Least privilege | Workloads should use only required data-plane permissions | Managed identities and resource-specific role assignments | Role definitions/assignments modeled; some identity-dependent assignments are unsupported in What-If until principal IDs exist | Verify effective RBAC after deployment and remove unnecessary grants |
| Observability | Failures in API, workers, messaging, and dependencies must be diagnosable | Application Insights + Log Analytics; architecture defines telemetry and runbook expectations | Resources/config are modeled; observability docs exist | Deploy, confirm telemetry coverage, diagnostic categories, alerting, and correlation across async flows |
| Recoverability | Failure modes must have explicit operational response | Front Door failover, Cosmos failover, DLQ behavior, retry/backoff, reservation expiry, and runbooks are documented | Reliability/DR documentation exists | Perform controlled recovery exercises and record results |
| Deployability | Infrastructure changes should be reviewable and repeatable | Modular Bicep, dev/test/prod params, PowerShell helpers, GitHub Actions, OIDC, ARM What-If | Compiler validation and live dev ARM What-If are green | Execute a deployment only after scope/cost review; validate post-deploy state |
| Cost | Dev should avoid unnecessary production spend; prod may cost more when requirements justify it | Lower-cost dev profile; more resilient/private production profile; expensive services are requirement-driven | Cost architecture documented | Measure actual deployed cost only if/when environments are created |
| Maintainability | Platform complexity should stay below the value it provides | App Service selected over AKS for current requirements; clear service boundaries and ADRs | ADRs and architecture docs are source-controlled | Re-evaluate AKS/other platforms only when Kubernetes-specific requirements appear |

## RTO/RPO stance

RTO and RPO are **business requirements**, not numbers invented by the reference architecture. The current documentation describes expected dependency behavior and candidate objectives, but no portfolio claim should present RTO/RPO as achieved until the corresponding deployment and recovery tests have been executed.

## Review questions

A reviewer should be able to challenge this matrix with the following questions:

- Which dependency prevents the system from being fully multi-region today?
- What consistency guarantee protects inventory?
- Which customer-facing paths are synchronous versus asynchronous?
- Which controls are design intent versus runtime-proven?
- What requirement would justify moving from App Service to AKS?
- Which recovery behavior still requires a real deployment test?
