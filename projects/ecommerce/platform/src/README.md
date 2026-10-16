# Application Implementation Contract

The infrastructure is designed for a .NET 8 Linux App Service implementation, but the architectural contract is language-agnostic.

## Temporary live-validation application

`ValidationApp/` is a deliberately small .NET 8 workload used only for the portfolio's controlled Azure validation run. It is **not** the completed commerce product and must not be presented as one.

The same published package runs in two modes based on the Bicep-provisioned `APP_COMPONENT` and `WORKER_ROLE` settings:

- the API exposes `/health` and `/ready`;
- token-protected validation endpoints can perform a synthetic Cosmos DB write/read/delete and publish a synthetic `ValidationProbe` event to Service Bus;
- the inventory, payment, shipping, and analytics worker instances consume their corresponding Service Bus subscriptions with managed identity and write idempotent validation receipts to Cosmos DB;
- Azure Monitor OpenTelemetry emits request/runtime telemetry through the provisioned Application Insights connection string.

The validation endpoints are disabled by default. `deploy-validation-app.ps1` enables them only for the temporary dev exercise and generates a random ephemeral token. The token is masked in GitHub Actions, stored only in the runner's temporary runtime directory, excluded from evidence artifacts, and deleted after smoke testing.

`smoke-test-validation.ps1` validates the intended public path through Front Door, verifies the direct App Service origin does not return a successful response, runs the synthetic Cosmos/Service Bus workflow, waits for all four worker subscriptions, verifies Application Insights has received request telemetry, deletes the synthetic Cosmos receipts, and writes a non-secret evidence record.

This workload is intentionally scoped to proving the deployed architecture's integration points before the Deployment Stack is destroyed for cost control.

## API endpoints expected by the full project

```text
GET    /health
GET    /ready
GET    /api/products
GET    /api/products/{id}
POST   /api/carts
GET    /api/carts/{id}
POST   /api/carts/{id}/items
DELETE /api/carts/{id}/items/{sku}
POST   /api/checkout
GET    /api/orders
GET    /api/orders/{id}
```

The temporary `ValidationApp` implements only `/health`, `/ready`, and the gated `/validation/*` proof endpoints; the business endpoints above remain the contract for a complete commerce implementation.

## App settings provisioned by Bicep

```text
APPLICATIONINSIGHTS_CONNECTION_STRING
AZURE_COSMOS_ENDPOINT
AZURE_COSMOS_DATABASE
SERVICEBUS__fullyQualifiedNamespace
KEYVAULT_URI
ANALYTICS_STORAGE_ACCOUNT
REGION
ASPNETCORE_ENVIRONMENT
APP_COMPONENT
WORKER_ROLE   # worker apps only
```

The validation deployment temporarily adds `ENABLE_VALIDATION_ENDPOINTS` and `VALIDATION_TOKEN` to the API App Service only. Neither value is an Azure resource credential.

Authentication to Azure services uses `DefaultAzureCredential`/managed identity. Do not introduce connection strings with Cosmos keys, Service Bus SAS keys, Storage keys, or other reusable Azure resource secrets unless there is a documented exception.

## Worker behavior for the complete application

### Inventory worker
Consumes relevant order/inventory events and owns reservation/commit/release state transitions.

### Payment worker
Calls a payment sandbox/provider. Must use provider idempotency keys so message redelivery cannot double-charge an order.

### Shipping worker
Creates simulated shipment/fulfillment state after payment/order confirmation.

### Analytics worker
Consumes business events and writes immutable raw events into Data Lake `bronze`, from which transformation jobs can create `silver` and `gold` datasets.

## Event envelope

```json
{
  "eventId": "guid",
  "eventType": "OrderCreated",
  "eventVersion": 1,
  "occurredUtc": "2026-10-10T20:00:00Z",
  "correlationId": "guid",
  "orderId": "guid",
  "payload": {}
}
```

Set the Service Bus `MessageId` to `eventId` and carry the correlation ID on the message as well. The validation app follows the same envelope structure with `eventType=ValidationProbe`.

## Required implementation tests for the complete application

- one-item/100-concurrent-checkout race
- payment failure releases inventory
- reservation timeout releases inventory
- duplicate message does not duplicate side effects
- poison message reaches DLQ
- direct App Service API access blocked while Front Door access succeeds
- regional origin failure causes Front Door failover
