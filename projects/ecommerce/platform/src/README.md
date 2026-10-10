# Application Implementation Contract

The infrastructure is designed for a .NET 8 Linux App Service implementation, but the architectural contract is language-agnostic.

## API endpoints expected by the project

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

Authentication should use `DefaultAzureCredential`/managed identity in Azure. Do not introduce connection strings with resource keys unless there is a documented exception.

## Worker behavior

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

Set the Service Bus `MessageId` to `eventId` and carry the correlation ID on the message as well.

## Required implementation tests

- one-item/100-concurrent-checkout race
- payment failure releases inventory
- reservation timeout releases inventory
- duplicate message does not duplicate side effects
- poison message reaches DLQ
- direct App Service API access blocked while Front Door access succeeds
- regional origin failure causes Front Door failover
