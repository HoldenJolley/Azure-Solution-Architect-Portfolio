# Testing Strategy

A deployable reference architecture needs tests for code and architectural behavior.

## IaC

```powershell
./scripts/validate.ps1 -Environment dev -RunWhatIf
```

Validate prod independently before a production-reference deployment.

## Temporary live validation run

The first live Azure exercise uses the `dev` profile and is intentionally temporary. The objective is to prove that the reference infrastructure can be created through an Azure Deployment Stack, exercised against a small validation workload, documented, and then removed cleanly without leaving an expensive environment running.

### Safety gates

Before creating resources:

1. lint/build the Bicep and parameter file;
2. authenticate to Azure using GitHub OIDC;
3. run the subscription-scope ARM What-If and review it;
4. use the fixed stack name `ecommerce-dev-validation-stack`;
5. require the manual GitHub Actions confirmation `DEPLOY-ECOMMERCE-dev`;
6. deploy only the `dev` environment for the portfolio validation run.

The Deployment Stack uses `action-on-unmanage=deleteAll` and deny mode `none`. Teardown is a separate manual workflow and requires the typed confirmation `DESTROY-ECOMMERCE-dev`.

### Infrastructure acceptance

Capture evidence that:

- the Deployment Stack reaches a successful provisioning state;
- the expected global and East US 2 resource groups exist;
- the single-region Front Door, App Service, Cosmos DB, Service Bus, Data Lake, Key Vault, monitoring, network, identities, and RBAC resources are present;
- no unintended secondary-region resources are deployed by the `dev` profile;
- deployment outputs include the Front Door hostname and primary API hostname;
- the GitHub Actions deployment artifact contains the stack metadata captured at deployment time.

### Runtime acceptance

A minimal validation application will be deployed separately from the infrastructure stack. It is not intended to implement the complete e-commerce product. It exists only to verify the architectural integration points needed for the portfolio evidence boundary.

The validation workload should prove:

- `GET /health` and `GET /ready` respond successfully through Front Door;
- direct access to the API App Service is rejected while the Front Door path succeeds;
- the API can authenticate with managed identity to Cosmos DB and perform a synthetic write/read/delete cycle;
- the API can publish a synthetic Service Bus event without using a namespace key/SAS credential;
- a validation worker can consume that event with managed identity;
- Application Insights/Log Analytics receives validation telemetry;
- no Azure resource keys are introduced into application settings.

Synthetic test data must be obviously non-production and should be deleted after verification where practical.

### Teardown acceptance

After evidence is captured:

1. run the separate destroy workflow;
2. delete the Deployment Stack with `action-on-unmanage=deleteAll`;
3. verify the expected resource groups no longer exist or document any asynchronous Azure cleanup still completing;
4. retain the cleanup artifact showing the stack identity and post-delete resource-group check;
5. confirm Cost Management has no remaining e-commerce validation resources accruing charges.

A successful run supports the claim: **the dev infrastructure was deployed to Azure through a Deployment Stack, functionally smoke-tested, evidence was captured, and the validation environment was intentionally decommissioned for cost control.** It does not by itself prove the complete production e-commerce application or the two-region production profile.

## Unit tests

Cover cart validation/math, inventory state transitions, reservation expiration, order transitions, event serialization/versioning, and idempotency decisions.

## Integration tests

Validate managed-identity access to Cosmos DB, Service Bus publish/consume, Key Vault access, analytics writes to Data Lake, Front Door health, and direct-origin rejection.

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

- direct origin blocked
- WAF test traffic detected/blocked per environment mode
- prod data-service public access blocked
- wrong managed identity denied
- no keys/passwords in application settings
- customer identity denied from admin operations
