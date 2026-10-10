param workloadName string
param environment string
param location string
param suffix string
param cosmosLocations array
param cosmosEnableMultipleWriteLocations bool
param cosmosDatabaseThroughput int

@allowed([
  'Standard'
  'Premium'
])
param serviceBusSkuName string

param dataLakeSkuName string
param enablePrivateNetworking bool
param tags object = {}

var cosmosAccountName = 'cos-${workloadName}-${environment}-${suffix}'
var cosmosDatabaseName = 'commerce'
var serviceBusNamespaceName = 'sb-${workloadName}-${environment}-${suffix}'
var keyVaultName = 'kv-${environment}-${suffix}'
var dataLakeAccountName = 'st${uniqueString(resourceGroup().id, workloadName, environment)}'
var publicNetworkAccess = enablePrivateNetworking ? 'Disabled' : 'Enabled'

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [for (region, index) in cosmosLocations: {
      locationName: region
      failoverPriority: index
      isZoneRedundant: false
    }]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableAutomaticFailover: !cosmosEnableMultipleWriteLocations
    enableMultipleWriteLocations: cosmosEnableMultipleWriteLocations
    disableLocalAuth: true
    publicNetworkAccess: publicNetworkAccess
    minimalTlsVersion: 'Tls12'
  }
}

resource commerceDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: cosmosDatabaseName
  parent: cosmos
  properties: {
    resource: { id: cosmosDatabaseName }
    options: { throughput: cosmosDatabaseThroughput }
  }
}

var containers = [
  { name: 'products', partitionKey: '/category' }
  { name: 'carts', partitionKey: '/userId' }
  { name: 'orders', partitionKey: '/userId' }
  { name: 'userProfiles', partitionKey: '/id' }
  { name: 'inventory', partitionKey: '/sku' }
  { name: 'reservations', partitionKey: '/sku' }
  { name: 'processedMessages', partitionKey: '/consumer' }
]

resource cosmosContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [for container in containers: {
  name: container.name
  parent: commerceDb
  properties: {
    resource: {
      id: container.name
      partitionKey: { paths: [container.partitionKey], kind: 'Hash' }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [{ path: '/*' }]
        excludedPaths: [{ path: '/"_etag"/?' }]
      }
    }
  }
}]

resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: serviceBusSkuName == 'Premium' ? { name: 'Premium', tier: 'Premium', capacity: 1 } : { name: 'Standard', tier: 'Standard' }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: true
    zoneRedundant: false
  }
}

resource commerceEvents 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = {
  name: 'commerce-events'
  parent: serviceBus
  properties: {
    defaultMessageTimeToLive: 'P14D'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: serviceBusSkuName == 'Standard'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    supportOrdering: false
    status: 'Active'
  }
}

var subscriptions = ['inventory' 'payment' 'shipping' 'analytics']
resource commerceSubscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' = [for subscriptionName in subscriptions: {
  name: subscriptionName
  parent: commerceEvents
  properties: {
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P14D'
    enableBatchedOperations: true
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    status: 'Active'
  }
}]

resource dataLake 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: dataLakeAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: dataLakeSkuName }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: publicNetworkAccess
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: dataLake
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 7 }
    containerDeleteRetentionPolicy: { enabled: true, days: 7 }
  }
}

var lakeContainers = ['bronze' 'silver' 'gold']
resource lakeContainerResources 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for containerName in lakeContainers: {
  name: containerName
  parent: blobService
  properties: { publicAccess: 'None' }
}]

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: publicNetworkAccess
  }
}

output cosmosAccountId string = cosmos.id
output cosmosAccountName string = cosmos.name
output cosmosEndpoint string = cosmos.properties.documentEndpoint
output cosmosDatabaseName string = commerceDb.name
output serviceBusNamespaceId string = serviceBus.id
output serviceBusNamespaceName string = serviceBus.name
output serviceBusFullyQualifiedNamespace string = '${serviceBus.name}.servicebus.windows.net'
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output dataLakeAccountId string = dataLake.id
output dataLakeAccountName string = dataLake.name
