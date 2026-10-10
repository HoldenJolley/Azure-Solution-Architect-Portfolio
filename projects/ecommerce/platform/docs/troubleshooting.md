# Troubleshooting

## Front Door returns 503

Check whether application code is deployed, `/health` is healthy, App Service restrictions have propagated, the origin hostname is correct, and the app started successfully.

## Direct App Service API returns 403

Expected. The API site accepts main-site traffic only from Azure Front Door with the profile-specific `X-Azure-FDID` header.

## Worker URL returns 403

Expected. Worker main endpoints are not public HTTP surfaces.

## App cannot reach data services in prod

Check App Service VNet integration, private-endpoint connection state, private DNS links/resolution, and managed-identity role assignment propagation.

## Service Bus private networking fails

Confirm the environment uses Service Bus Premium and that the private endpoint/DNS zone is healthy.

## RBAC deployment fails

The deployment identity probably lacks `Microsoft.Authorization/roleAssignments/write` permissions.

## Cosmos ARM Contributor cannot read/write items

Expected. Cosmos DB NoSQL data-plane RBAC is separate from ordinary Azure Resource Manager roles. Use Cosmos-native SQL role assignments.

## Region or SKU unavailable

Change region/SKU parameters or request quota. Do not assume every subscription has every SKU available in every region.
