# Threat Model

This lightweight STRIDE-oriented model should be revisited when customer identity, payment integration, and administrative APIs are implemented.

| Area | Threat | Primary controls | Validation |
|---|---|---|---|
| Public API | Direct-origin bypass | Front Door-only App Service restriction, `X-Azure-FDID`, WAF | Direct origin returns 403; Front Door succeeds |
| API | Credential theft | Managed identity; no platform keys in settings | Scan settings/repo for secrets |
| Cosmos DB | Unauthorized access | Local auth disabled, data-plane RBAC, private endpoints in prod | Identity-specific/public-access tests |
| Service Bus | Message injection/reading | Local auth disabled, sender/receiver RBAC, private endpoint in prod | Identity-specific integration tests |
| Key Vault | Secret disclosure | RBAC, private endpoint in prod | Access review/logs |
| Data Lake | Exfiltration | Shared key disabled, scoped analytics identity, private endpoint | Attempt access using API identity |
| Checkout | Double sale | Atomic/conditional reservation | 100-client/1-item test |
| Workers | Duplicate side effects | Consumer idempotency records, message IDs | Replay same event |
| Messaging | Poison events | Retry limit, DLQ, runbook | Inject invalid payload |
| Payments | Double charge | Provider idempotency key tied to payment attempt | Redelivery test |
| Admin | Privilege escalation | Separate administrative authorization | Authorization tests |
| Telemetry | Sensitive-data leakage | Structured logging allowlist | Log inspection |
| Supply chain | Malicious dependency/workflow | Protected branches, scanning, minimal workflow permissions | CI checks |
| Deployment | Cloud credential theft | GitHub OIDC | Verify no Azure client secret |

## Trust boundaries

1. Internet -> Front Door/WAF.
2. Front Door -> App Service origin.
3. Application identities -> Azure data services.
4. Service Bus -> asynchronous workers.
5. Operational commerce plane -> analytics/data lake plane.
6. GitHub Actions -> Azure control plane.
7. Payment worker -> external payment provider.

## Data classification

- Product catalog: public/business data.
- Inventory and orders: confidential business data.
- Customer profile: personal data; minimize fields and retention.
- Payment card data: **out of scope**; do not store PAN/CVV.
- Telemetry: potentially sensitive operational data; avoid tokens/request bodies by default.
