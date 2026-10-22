# Testing Strategy

A deployable reference architecture needs tests for code and architectural behavior.

## IaC

```powershell
./scripts/validate.ps1 -Environment dev -RunWhatIf
```

The validation script now checks both the complete reference architecture (`main.bicep`) and the temporary live-validation template (`validation.bicep`). For `dev`, the ARM What-If is run against the exact temporary validation template that will be deployed. Validate prod independently before a production-reference deployment.

## Temporary live validation run

The live Azure exercise is intentionally temporary. Its objective is to prove that the App Service, Cosmos DB, Service Bus, Data Lake, Key Vault, monitoring, network, managed-identity, and RBAC portions of the design can be created through an Azure Deployment Stack, exercised against a small validation workload, documented, and then removed cleanly.

The validation subscription is a Free Trial/Student-class subscription. Azure rejects Azure Front Door resource creation on this subscription type. The complete reference architecture still contains Azure Front Door and WAF, but the temporary `dev.validation.bicepparam` profile uses `validation.bicep`, which intentionally omits Front Door/WAF and exposes only the validation API App Service directly for the short test window. This is a validation-environment exception, not a change to the intended reference architecture.

### Safety gates

Before creating resources:

1. lint/build both the reference and temporary validation Bicep templates;
2. authenticate to Azure using GitHub OIDC;
3. run the subscription-scope ARM What-If against the exact temporary validation template;
4. use the fixed stack name `ecommerce-dev-validation-stack`;
5. require the manual GitHub Actions confirmation `DEPLOY-ECOMMERCE-dev`;
6. deploy only the `dev` validation environment for the portfolio validation run;
7. assign an explicit validation TTL of 4, 8, or 12 hours, with 8 hours as the default.

The Deployment Stack uses `action-on-unmanage=deleteAll` and deny mode `none`. Teardown remains available as a separate manual workflow requiring the typed confirmation `DESTROY-ECOMMERCE-dev`.

For live validation deployments, the infrastructure workflow also stamps the validation resource groups with `validationEphemeral=true`, `validationExpiresAtUtc=<UTC timestamp>`, and `validationTtlHours=<hours>`. The independent `e-commerce validation expiry cleanup` workflow checks every 15 minutes using the `dev` GitHub environment/OIDC identity. It only authorizes automatic teardown when the resource group is explicitly marked ephemeral, the expiry timestamp is valid and in the past, and the managed Deployment Stack exists. It then calls the same guarded `destroy.ps1` path used by manual teardown and uploads cleanup evidence. It intentionally refuses direct resource-group deletion if the Deployment Stack cannot be found.

The TTL stamp runs with `if: always()` after a deployment attempt, so resource groups created by a partially failed stack can still receive expiry metadata where they exist. If no resource group exists, no TTL metadata is written.

### Infrastructure acceptance

Capture evidence that:

- the Deployment Stack reaches a successful provisioning state;
- the expected global and East US 2 resource groups exist;
- App Service, Cosmos DB, Service Bus, Data Lake, Key Vault, monitoring, network, identities, and RBAC resources are present;
- no unintended secondary-region resources are deployed by the validation profile;
- deployment outputs include the direct validation API hostname and runtime entry URL;
- Front Door is explicitly recorded as not runtime-validated because the subscription blocks its creation;
- the GitHub Actions deployment artifact contains sanitized stack metadata captured at deployment time;
- the deployment evidence records the configured TTL and expiration timestamp.

### Runtime acceptance

A minimal validation application is deployed separately from the infrastructure stack. It is not intended to implement the complete e-commerce product. It exists only to verify the architectural integration points needed for the portfolio evidence boundary.

The validation workload should prove:

- `GET /health` responds successfully through the temporary runtime entry point;
- the public validation endpoints return `401` without the ephemeral validation token;
- the API can authenticate with managed identity to Cosmos DB and perform a synthetic write/read/delete cycle;
- the API can publish a synthetic Service Bus event without using a namespace key/SAS credential;
- the inventory, payment, shipping, and analytics workers consume the synthetic event with managed identities;
- Cosmos DB local/key authentication is disabled;
- Service Bus local/SAS authentication is disabled;
- Application Insights receives request telemetry;
- no reusable Azure resource keys/passwords are introduced into application settings;
- synthetic validation receipts are deleted after verification;
- temporary validation endpoint settings and the ephemeral token are removed after the smoke test.

Because Front Door cannot be provisioned on this subscription, this particular run does **not** prove Front Door/WAF runtime behavior or direct-origin blocking. Those remain reference-architecture controls rather than live-validation evidence from this subscription.

Synthetic test data must be obviously non-production and should be deleted after verification where practical.

### Teardown acceptance

After evidence is captured, either run the separate manual destroy workflow or allow the configured TTL to expire. In either case:

1. delete the Deployment Stack with `action-on-unmanage=deleteAll`;
2. verify the expected resource groups no longer exist or document any asynchronous Azure cleanup still completing;
3. retain the cleanup artifact showing the stack identity and post-delete resource-group check;
4. confirm Cost Management has no remaining e-commerce validation resources accruing charges.

For TTL-driven cleanup, the scheduled workflow may run shortly after the exact expiration timestamp rather than at the exact second because it evaluates expiry on a 15-minute cadence and GitHub-hosted scheduled jobs can be delayed. The expiry timestamp is therefore a minimum lifetime boundary, not a real-time scheduler guarantee.

A successful run supports the claim: **the e-commerce validation infrastructure was deployed to Azure through a Deployment Stack, managed-identity Cosmos DB and Service Bus paths were functionally smoke-tested, evidence was captured, and the environment was intentionally decommissioned for cost control. Azure Front Door/WAF was not runtime-provisioned because the validation subscription forbids those resources.** It does not by itself prove the complete production e-commerce application or the two-region production profile.

## Unit tests

Cover cart validation/math, inventory state transitions, reservation expiration, order transitions, event serialization/versioning, and idempotency decisions.

## Integration tests

Validate managed-identity access to Cosmos DB, Service Bus publish/consume, Key Vault access, analytics writes to Data Lake, Front Door health, and direct-origin rejection when tested on a subscription that permits Front Door.

## Last-item concurrency test

Precondition: one unit of a SKU. Send 100 concurrent reservation/checkout attempts.

Acceptance: exactly one succeeds, 99 fail as unavailable/conflict, inventory never becomes negative, and only one active/committed reservation exists.

## Idempotency

Deliver the same event/message repeatedly using the same `eventId`/`MessageId`. There must be one business side effect; duplicates are safely acknowledged and recorded as processed.

## Failure tests

- payment provider timeout/failure
- reservation expiration
- worker crash after side effect but before message completion
- poison event -> DLQ
- retry exhaustion
- Cosmos throttling/transient errors
- primary App Service origin failure
- analytics outage without commerce outage

## Observability acceptance

Given `correlationId`, reconstruct the checkout across API, Service Bus, workers, payment result, inventory, and final order state. Alert on sustained API failures/latency, DLQ messages, and abnormal backlog.

## Security tests

- validation endpoint denies missing/invalid token during the temporary direct-App-Service test
- direct origin blocked when Front Door is available on an eligible subscription
- WAF test traffic detected/blocked per environment mode when Front Door is available
- prod data-service public access blocked
- wrong managed identity denied
- no keys/passwords in application settings
- customer identity denied from admin operations
