targetScope = 'subscription'

@description('Short workload name used in Azure resource names.')
param workloadName string = 'ecommerce'

@allowed([
  'dev'
])
@description('Temporary live validation environment. Intentionally dev-only.')
param environment string = 'dev'

@description('Primary Azure region.')
param primaryLocation string = 'eastus2'

@description('Short code for the primary region.')
param primaryRegionCode string = 'eus2'

@allowed([
  'Standard'
  'Premium'
])
@description('Azure Service Bus SKU.')
param serviceBusSkuName string = 'Standard'

@description('Create private endpoints for data services. The temporary dev validation profile keeps this false.')
param enablePrivateNetworking bool = false

@description('Shared database throughput for the Cosmos DB commerce database.')
param cosmosDatabaseThroughput int = 1000

@description('App Service plan SKU name.')
param appServicePlanSkuName string = 'B1'

@description('App Service plan SKU tier.')
param appServicePlanSkuTier string = 'Basic'

@description('Data Lake storage SKU.')
param dataLakeSkuName string = 'Standard_LRS'

@description('Tags applied to resource groups and child resources where supported.')
param tags object = {
  workload: workloadName
  environment: environment
  managedBy: 'Bicep'
  portfolio: 'AzureSolutionArchitect'
  validationProfile: 'free-trial-no-front-door'
}

// Rotate the validation-only resource suffix after the first failed live attempt. This avoids
// collisions with soft-deleted globally named resources such as the purge-protected Key Vault.
var suffix = uniqueString(subscription().id, workloadName, environment, 'validation-v2')
var globalRgName = 'rg-${workloadName}-${environment}-global'
var primaryRgName = 'rg-${workloadName}-${environment}-${primaryRegionCode}'
var primaryAddressSpace = '10.10.0.0/16'
var primaryAppSubnetPrefix = '10.10.1.0/24'
var primaryPrivateEndpointSubnetPrefix = '10.10.2.0/24'

resource globalRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: globalRgName
  location: primaryLocation
  tags: tags
}

resource primaryRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: primaryRgName
  location: primaryLocation
  tags: tags
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: globalRg
  params: {
    workloadName: workloadName
    environment: environment
    location: primaryLocation
    suffix: suffix
    tags: tags
  }
}

module primaryNetwork './modules/network.bicep' = {
  name: 'network-primary'
  scope: primaryRg
  params: {
    workloadName: workloadName
    environment: environment
    location: primaryLocation
    regionCode: primaryRegionCode
    addressSpace: primaryAddressSpace
    appSubnetPrefix: primaryAppSubnetPrefix
    privateEndpointSubnetPrefix: primaryPrivateEndpointSubnetPrefix
    tags: tags
  }
}

module data './modules/data.bicep' = {
  name: 'shared-data'
  scope: globalRg
  params: {
    workloadName: workloadName
    environment: environment
    location: primaryLocation
    suffix: suffix
    cosmosLocations: [
      primaryLocation
    ]
    cosmosEnableMultipleWriteLocations: false
    cosmosDatabaseThroughput: cosmosDatabaseThroughput
    serviceBusSkuName: serviceBusSkuName
    dataLakeSkuName: dataLakeSkuName
    enablePrivateNetworking: enablePrivateNetworking
    tags: tags
  }
}

module primaryApps './modules/regional-apps.bicep' = {
  name: 'apps-primary'
  scope: primaryRg
  params: {
    workloadName: workloadName
    environment: environment
    location: primaryLocation
    regionCode: primaryRegionCode
    suffix: suffix
    appServicePlanSkuName: appServicePlanSkuName
    appServicePlanSkuTier: appServicePlanSkuTier
    appSubnetId: primaryNetwork.outputs.appSubnetId
    frontDoorId: ''
    restrictApiToFrontDoor: false
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    cosmosEndpoint: data.outputs.cosmosEndpoint
    cosmosDatabaseName: data.outputs.cosmosDatabaseName
    serviceBusFullyQualifiedNamespace: data.outputs.serviceBusFullyQualifiedNamespace
    keyVaultUri: data.outputs.keyVaultUri
    dataLakeAccountName: data.outputs.dataLakeAccountName
    tags: tags
  }
}

module privateDns './modules/private-dns.bicep' = if (enablePrivateNetworking) {
  name: 'private-dns'
  scope: globalRg
  params: {
    vnetIds: [
      primaryNetwork.outputs.vnetId
    ]
    tags: tags
  }
}

module primaryPrivateEndpoints './modules/private-endpoints.bicep' = if (enablePrivateNetworking) {
  name: 'private-endpoints-primary'
  scope: primaryRg
  params: {
    location: primaryLocation
    regionCode: primaryRegionCode
    privateEndpointSubnetId: primaryNetwork.outputs.privateEndpointSubnetId
    cosmosAccountId: data.outputs.cosmosAccountId
    serviceBusNamespaceId: data.outputs.serviceBusNamespaceId
    keyVaultId: data.outputs.keyVaultId
    dataLakeAccountId: data.outputs.dataLakeAccountId
    cosmosPrivateDnsZoneId: privateDns!.outputs.cosmosPrivateDnsZoneId
    serviceBusPrivateDnsZoneId: privateDns!.outputs.serviceBusPrivateDnsZoneId
    keyVaultPrivateDnsZoneId: privateDns!.outputs.keyVaultPrivateDnsZoneId
    blobPrivateDnsZoneId: privateDns!.outputs.blobPrivateDnsZoneId
    dfsPrivateDnsZoneId: privateDns!.outputs.dfsPrivateDnsZoneId
    tags: tags
  }
}

module rbac './modules/rbac.bicep' = {
  name: 'rbac'
  scope: globalRg
  params: {
    cosmosAccountName: data.outputs.cosmosAccountName
    serviceBusNamespaceName: data.outputs.serviceBusNamespaceName
    keyVaultName: data.outputs.keyVaultName
    dataLakeAccountName: data.outputs.dataLakeAccountName
    apiPrincipalIds: [
      primaryApps.outputs.apiPrincipalId
    ]
    workerPrincipalIds: primaryApps.outputs.workerPrincipalIds
    analyticsPrincipalIds: [
      primaryApps.outputs.analyticsPrincipalId
    ]
    keyVaultPrincipalIds: [
      primaryApps.outputs.paymentPrincipalId
    ]
  }
}

output validationProfile string = 'free-trial-compatible-no-front-door'
output frontDoorDeployed bool = false
output frontDoorUrl string = ''
output primaryApiHostName string = primaryApps.outputs.apiDefaultHostName
output runtimeEntryUrl string = 'https://${primaryApps.outputs.apiDefaultHostName}'
output cosmosEndpoint string = data.outputs.cosmosEndpoint
output serviceBusNamespace string = data.outputs.serviceBusFullyQualifiedNamespace
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
