# Networking Architecture

## Edge ingress

Azure Front Door is the global ingress point. The API App Service retains a public default endpoint in this baseline, but App Service access restrictions allow only traffic from the `AzureFrontDoor.Backend` service tag that also carries the Front Door profile's `X-Azure-FDID` header.

This prevents a normal client from bypassing Front Door/WAF by calling the App Service hostname directly.

## Regional VNets

Each region receives a separate VNet because Azure VNets are regional resources.

```text
East US 2: 10.10.0.0/16
  snet-app               10.10.1.0/24
  snet-private-endpoints 10.10.2.0/24

West US 2: 10.20.0.0/16
  snet-app               10.20.1.0/24
  snet-private-endpoints 10.20.2.0/24
```

The App Service subnet is delegated to `Microsoft.Web/serverFarms` for regional VNet integration.

## Private networking in prod

When `enablePrivateNetworking=true`, the template disables public network access on Cosmos DB, Service Bus, Key Vault, and Data Lake; creates private endpoints in each deployed application region; and links the appropriate private DNS zones for Cosmos DB, Service Bus, Key Vault, Blob, and DFS endpoints.

## Front Door origin hardening

The baseline uses Front Door-aware App Service access restrictions so dev can remain on Front Door Standard. A later Premium hardening phase can use Front Door Private Link to App Service and disable public origin access entirely.

## Optional hub-and-spoke extension

Azure Firewall, Bastion, hybrid gateways, forced-tunnel route tables, and DNS Private Resolver are intentionally omitted from the baseline because they materially increase lab cost. Add them when centralized egress inspection, hybrid connectivity, or shared network services are actual requirements.
