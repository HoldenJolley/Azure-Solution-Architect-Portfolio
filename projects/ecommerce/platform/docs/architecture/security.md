# Security Architecture

## Identity-first access

Application components use system-assigned managed identities. Data-plane access is granted through RBAC instead of embedding Azure resource keys.

| Component | Cosmos | Service Bus Send | Service Bus Receive | Key Vault | Data Lake |
|---|---:|---:|---:|---:|---:|
| API | Contributor | Yes | No | No | No |
| Inventory/Shipping workers | Contributor | Yes | Yes | No | No |
| Payment worker | Contributor | Yes | Yes | Secrets User | No |
| Analytics worker | No | No | Yes | No | Blob Data Contributor |

Cosmos permissions use Cosmos-native data-plane RBAC, not the Azure Resource Manager Contributor role.

## Secret handling

- Cosmos local authentication disabled.
- Service Bus local/SAS authentication disabled.
- Storage Shared Key access disabled.
- Key Vault uses Azure RBAC.
- Bicep parameters contain resource configuration, not credentials.
- GitHub Actions uses OIDC/federated Azure authentication.

A real payment-provider credential belongs in Key Vault. The payment worker is the only workload identity intended to receive payment-secret access.

## Edge controls

- HTTPS only.
- Front Door WAF at global ingress.
- Production uses Prevention mode and managed rules.
- API origin is restricted to `AzureFrontDoor.Backend` plus the profile-specific `X-Azure-FDID` header.
- Worker main endpoints default-deny inbound HTTP traffic.

## Private data plane

Production disables public network access on Cosmos DB, Service Bus, Key Vault, and Data Lake and reaches those services through regional private endpoints and private DNS.

## Customer identity boundary

Customer authentication is intentionally left as an integration boundary. The backend should map a stable external identity subject to `userProfiles`. Customer and administrative authorization must be separate, and administrative catalog/inventory APIs must require explicit privileged roles.

## Payment boundary

The platform does not store PAN/CVV. Payment processing should use a provider sandbox/tokenization API and persist only non-sensitive provider references, state, amount, timestamps, and idempotency metadata required for the order workflow.
