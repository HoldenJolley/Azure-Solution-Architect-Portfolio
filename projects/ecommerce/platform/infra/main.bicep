targetScope = 'subscription'

@description('Short workload name used in Azure resource names.')
param workloadName string = 'ecommerce'

@allowed(['dev' 'test' 'prod'])
@description('Deployment environment.')
param environment string = 'dev'

@description('Primary Azure region.')
param primaryLocation string = 'eastus2'
@description('Short code for the primary region.')
param primaryRegionCode string = 'eus2'
@description('Secondary Azure region used for multi-region deployments.')
param secondaryLocation string = 'westus2'
@description('Short code for the secondary region.')
param secondaryRegionCode string = 'wus2'
@description('Deploy a second regional application stack and add it to Azure Front Door.')
param enableSecondaryRegion bool = false

@allowed(['Standard_AzureFrontDoor' 'Premium_AzureFrontDoor'])
param frontDoorSkuName string = 'Standard_AzureFrontDoor'
@allowed(['Standard' 'Premium'])
param serviceBusSkuName string = 'Standard'
param enablePrivateNetworking bool = false
param cosmosEnableMultipleWriteLocations bool = false
param cosmosDatabaseThroughput int = 1000
param appServicePlanSkuName string = 'S1'
param appServicePlanSkuTier string = 'Standard'
param dataLakeSkuName string = 'Standard_LRS'
@allowed(['Detection' 'Prevention'])
param wafMode string = 'Detection'
param tags object = {
  workload: workloadName
  environment: environment
  managedBy: 'Bicep'
  portfolio: 'AzureSolutionArchitect'
}

var suffix = uniqueString(subscription().id, workloadName, environment)
var globalRgName = 'rg-${workloadName}-${environment}-global'
var primaryRgName = 'rg-${workloadName}-${environment}-${primaryRegionCode}'
var secondaryRgName = 'rg-${workloadName}-${environment}-${secondaryRegionCode}'
var frontDoorProfileName = 'afd-${workloadName}-${environment}-${suffix}'
var frontDoorEndpointName = 'afd-${suffix}'

resource globalRg 'Microsoft.Resources/resourceGroups@2024-11-01' = { name: globalRgName, location: primaryLocation, tags: tags }
resource primaryRg 'Microsoft.Resources/resourceGroups@2024-11-01' = { name: primaryRgName, location: primaryLocation, tags: tags }
resource secondaryRg 'Microsoft.Resources/resourceGroups@2024-11-01' = if (enableSecondaryRegion) { name: secondaryRgName, location: secondaryLocation, tags: tags }

module frontDoorProfile './modules/frontdoor-profile.bicep' = {
  name: 'front-door-profile'
  scope: globalRg
  params: { profileName: frontDoorProfileName, endpointName: frontDoorEndpointName, skuName: frontDoorSkuName, wafMode: wafMode, tags: tags }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: globalRg
  params: { workloadName: workloadName, environment: environment, location: primaryLocation, suffix: suffix, tags: tags }
}

module primaryNetwork './modules/network.bicep' = {
  name: 'network-primary'
  scope: primaryRg
  params: { workloadName: workloadName, environment: environment, location: primaryLocation, regionCode: primaryRegionCode, addressSpace: '10.10.0.0/16', appSubnetPrefix: '10.10.1.0/24', privateEndpointSubnetPrefix: '10.10.2.0/24', tags: tags }
}

module secondaryNetwork './modules/network.bicep' = if (enableSecondaryRegion) {
  name: 'network-secondary'
  scope: secondaryRg
  params: { workloadName: workloadName, environment: environment, location: secondaryLocation, regionCode: secondaryRegionCode, addressSpace: '10.20.0.0/16', appSubnetPrefix: '10.20.1.0/24', privateEndpointSubnetPrefix: '10.20.2.0/24', tags: tags }
}

var cosmosLocations = enableSecondaryRegion ? [primaryLocation, secondaryLocation] : [primaryLocation]
module data './modules/data.bicep' = {
  name: 'shared-data'
  scope: globalRg
  params: { workloadName: workloadName, environment: environment, location: primaryLocation, suffix: suffix, cosmosLocations: cosmosLocations, cosmosEnableMultipleWriteLocations: cosmosEnableMultipleWriteLocations, cosmosDatabaseThroughput: cosmosDatabaseThroughput, serviceBusSkuName: serviceBusSkuName, dataLakeSkuName: dataLakeSkuName, enablePrivateNetworking: enablePrivateNetworking, tags: tags }
}

module primaryApps './modules/regional-apps.bicep' = {
  name: 'apps-primary'
  scope: primaryRg
  params: { workloadName: workloadName, environment: environment, location: primaryLocation, regionCode: primaryRegionCode, suffix: suffix, appServicePlanSkuName: appServicePlanSkuName, appServicePlanSkuTier: appServicePlanSkuTier, appSubnetId: primaryNetwork.outputs.appSubnetId, frontDoorId: frontDoorProfile.outputs.frontDoorId, applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString, cosmosEndpoint: data.outputs.cosmosEndpoint, cosmosDatabaseName: data.outputs.cosmosDatabaseName, serviceBusFullyQualifiedNamespace: data.outputs.serviceBusFullyQualifiedNamespace, keyVaultUri: data.outputs.keyVaultUri, dataLakeAccountName: data.outputs.dataLakeAccountName, tags: tags }
}

module secondaryApps './modules/regional-apps.bicep' = if (enableSecondaryRegion) {
  name: 'apps-secondary'
  scope: secondaryRg
  params: { workloadName: workloadName, environment: environment, location: secondaryLocation, regionCode: secondaryRegionCode, suffix: suffix, appServicePlanSkuName: appServicePlanSkuName, appServicePlanSkuTier: appServicePlanSkuTier, appSubnetId: secondaryNetwork.outputs.appSubnetId, frontDoorId: frontDoorProfile.outputs.frontDoorId, applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString, cosmosEndpoint: data.outputs.cosmosEndpoint, cosmosDatabaseName: data.outputs.cosmosDatabaseName, serviceBusFullyQualifiedNamespace: data.outputs.serviceBusFullyQualifiedNamespace, keyVaultUri: data.outputs.keyVaultUri, dataLakeAccountName: data.outputs.dataLakeAccountName, tags: tags }
}

var frontDoorOrigins = enableSecondaryRegion ? [
  { name: 'primary', hostName: primaryApps.outputs.apiDefaultHostName, priority: 1, weight: 1000, enabled: true }
  { name: 'secondary', hostName: secondaryApps.outputs.apiDefaultHostName, priority: 1, weight: 1000, enabled: true }
] : [
  { name: 'primary', hostName: primaryApps.outputs.apiDefaultHostName, priority: 1, weight: 1000, enabled: true }
]

module frontDoorRouting './modules/frontdoor-routing.bicep' = {
  name: 'front-door-routing'
  scope: globalRg
  params: { profileName: frontDoorProfile.outputs.profileName, endpointName: frontDoorProfile.outputs.endpointName, wafPolicyId: frontDoorProfile.outputs.wafPolicyId, origins: frontDoorOrigins }
}

var vnetIds = enableSecondaryRegion ? [primaryNetwork.outputs.vnetId, secondaryNetwork.outputs.vnetId] : [primaryNetwork.outputs.vnetId]
module privateDns './modules/private-dns.bicep' = if (enablePrivateNetworking) {
  name: 'private-dns'
  scope: globalRg
  params: { vnetIds: vnetIds, tags: tags }
}

module primaryPrivateEndpoints './modules/private-endpoints.bicep' = if (enablePrivateNetworking) {
  name: 'private-endpoints-primary'
  scope: primaryRg
  params: { location: primaryLocation, regionCode: primaryRegionCode, privateEndpointSubnetId: primaryNetwork.outputs.privateEndpointSubnetId, cosmosAccountId: data.outputs.cosmosAccountId, serviceBusNamespaceId: data.outputs.serviceBusNamespaceId, keyVaultId: data.outputs.keyVaultId, dataLakeAccountId: data.outputs.dataLakeAccountId, cosmosPrivateDnsZoneId: privateDns.outputs.cosmosPrivateDnsZoneId, serviceBusPrivateDnsZoneId: privateDns.outputs.serviceBusPrivateDnsZoneId, keyVaultPrivateDnsZoneId: privateDns.outputs.keyVaultPrivateDnsZoneId, blobPrivateDnsZoneId: privateDns.outputs.blobPrivateDnsZoneId, dfsPrivateDnsZoneId: privateDns.outputs.dfsPrivateDnsZoneId, tags: tags }
}

module secondaryPrivateEndpoints './modules/private-endpoints.bicep' = if (enablePrivateNetworking && enableSecondaryRegion) {
  name: 'private-endpoints-secondary'
  scope: secondaryRg
  params: { location: secondaryLocation, regionCode: secondaryRegionCode, privateEndpointSubnetId: secondaryNetwork.outputs.privateEndpointSubnetId, cosmosAccountId: data.outputs.cosmosAccountId, serviceBusNamespaceId: data.outputs.serviceBusNamespaceId, keyVaultId: data.outputs.keyVaultId, dataLakeAccountId: data.outputs.dataLakeAccountId, cosmosPrivateDnsZoneId: privateDns.outputs.cosmosPrivateDnsZoneId, serviceBusPrivateDnsZoneId: privateDns.outputs.serviceBusPrivateDnsZoneId, keyVaultPrivateDnsZoneId: privateDns.outputs.keyVaultPrivateDnsZoneId, blobPrivateDnsZoneId: privateDns.outputs.blobPrivateDnsZoneId, dfsPrivateDnsZoneId: privateDns.outputs.dfsPrivateDnsZoneId, tags: tags }
}

var apiPrincipalIds = enableSecondaryRegion ? [primaryApps.outputs.apiPrincipalId, secondaryApps.outputs.apiPrincipalId] : [primaryApps.outputs.apiPrincipalId]
var workerPrincipalIds = enableSecondaryRegion ? concat(primaryApps.outputs.workerPrincipalIds, secondaryApps.outputs.workerPrincipalIds) : primaryApps.outputs.workerPrincipalIds
var analyticsPrincipalIds = enableSecondaryRegion ? [primaryApps.outputs.analyticsPrincipalId, secondaryApps.outputs.analyticsPrincipalId] : [primaryApps.outputs.analyticsPrincipalId]
var keyVaultPrincipalIds = enableSecondaryRegion ? [primaryApps.outputs.paymentPrincipalId, secondaryApps.outputs.paymentPrincipalId] : [primaryApps.outputs.paymentPrincipalId]

module rbac './modules/rbac.bicep' = {
  name: 'rbac'
  scope: globalRg
  params: { cosmosAccountName: data.outputs.cosmosAccountName, serviceBusNamespaceName: data.outputs.serviceBusNamespaceName, keyVaultName: data.outputs.keyVaultName, dataLakeAccountName: data.outputs.dataLakeAccountName, apiPrincipalIds: apiPrincipalIds, workerPrincipalIds: workerPrincipalIds, analyticsPrincipalIds: analyticsPrincipalIds, keyVaultPrincipalIds: keyVaultPrincipalIds }
}

output frontDoorHostName string = frontDoorProfile.outputs.endpointHostName
output frontDoorUrl string = 'https://${frontDoorProfile.outputs.endpointHostName}'
output primaryApiHostName string = primaryApps.outputs.apiDefaultHostName
output cosmosEndpoint string = data.outputs.cosmosEndpoint
output serviceBusNamespace string = data.outputs.serviceBusFullyQualifiedNamespace
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
