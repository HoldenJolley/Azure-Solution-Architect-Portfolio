# Networking Architecture

## Ingress

Internet traffic terminates at Azure Front Door Premium with WAF. Front Door reaches the Container Apps environment over its managed Private Link connection. The Container Apps environment has `publicNetworkAccess=Disabled` and is VNet-integrated/internal.

## Application isolation

The gateway uses external ACA ingress only within the internal environment so Front Door can reach it. The inference app uses internal ingress and is not an Internet origin.

## Private services

Private endpoints and Private DNS are created for:

- Key Vault: `privatelink.vaultcore.azure.net`
- Azure Container Registry: `privatelink.azurecr.io`
- Azure Managed Redis: `privatelink.redis.azure.net`

## Subnets

- `10.40.0.0/23` — delegated to Container Apps environment.
- `10.40.2.0/24` — private endpoints.
- `10.40.3.0/24` — reserved management/runner extension.

## Egress

Production environments should add explicit egress governance (Azure Firewall/NVA or equivalent) if the customer model must be prevented from calling arbitrary Internet destinations. The base landing zone avoids adding an expensive firewall automatically, but `imagePersistence=prohibited` assumes customer code is reviewed and egress is appropriately restricted for the risk profile.
