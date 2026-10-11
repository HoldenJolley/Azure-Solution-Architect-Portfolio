targetScope = 'subscription'

@description('Short workload name used in resource names.')
param workloadName string = 'ageverify'

@allowed(['dev', 'test', 'prod'])
param environment string

param location string

@description('Enable Azure Managed Redis for distributed short-lived session/replay state.')
param deploySessionStore bool = true

@description('Enable a dedicated confidential-compute profile. Only deploy in a currently supported ACA confidential-compute region.')
param enableConfidentialCompute bool = false

@description('Dedicated workload profile used by standard inference workloads.')
param workloadProfileType string = 'D4'

@description('Confidential workload profile type, for example DC4.')
param confidentialWorkloadProfileType string = 'DC4'

@description('Azure Managed Redis SKU.')
param redisSku string = 'Balanced_B0'

param tags object = {}

var prefix = toLower('${workloadName}-${environment}')
var commonTags = union(tags, {
  workload: workloadName
  environment: environment
  dataClassification: 'highly-sensitive-transient'
  imagePersistence: 'prohibited'
  managedBy: 'bicep'
})
var containerAppsSubnetId = resourceId(subscription().subscriptionId, rgNetwork.name, 'Microsoft.Network/virtualNetworks/subnets', '${prefix}-vnet', 'snet-containerapps')
var logAnalyticsWorkspaceId = resourceId(subscription().subscriptionId, rgMonitor.name, 'Microsoft.OperationalInsights/workspaces', '${prefix}-law')

resource rgNetwork 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-network-rg'
  location: location
  tags: commonTags
}

resource rgPlatform 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-platform-rg'
  location: location
  tags: commonTags
}

resource rgSecurity 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-security-rg'
  location: location
  tags: commonTags
}

resource rgMonitor 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-monitor-rg'
  location: location
  tags: commonTags
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rgMonitor
  params: {
    prefix: prefix
    location: location
    environment: environment
    tags: commonTags
  }
}

module network './modules/network.bicep' = {
  name: 'network'
  scope: rgNetwork
  params: {
    prefix: prefix
    location: location
    tags: commonTags
  }
}

module identities './modules/identities.bicep' = {
  name: 'identities'
  scope: rgSecurity
  params: {
    prefix: prefix
    location: location
    tags: commonTags
  }
}

module vault './modules/key-vault.bicep' = {
  name: 'keyVault'
  scope: rgSecurity
  params: {
    prefix: prefix
    location: location
    tags: commonTags
  }
}

module registry './modules/registry.bicep' = {
  name: 'registry'
  scope: rgPlatform
  params: {
    prefix: prefix
    location: location
    tags: commonTags
  }
}

module containerEnvironment './modules/container-environment.bicep' = {
  name: 'containerEnvironment'
  scope: rgPlatform
  params: {
    prefix: prefix
    location: location
    infrastructureSubnetId: containerAppsSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    workloadProfileType: workloadProfileType
    enableConfidentialCompute: enableConfidentialCompute
    confidentialWorkloadProfileType: confidentialWorkloadProfileType
    tags: commonTags
  }
  dependsOn: [
    monitoring
    network
  ]
}

module sessionStore './modules/redis.bicep' = if (deploySessionStore) {
  name: 'sessionStore'
  scope: rgPlatform
  params: {
    prefix: prefix
    location: location
    skuName: redisSku
    tags: commonTags
  }
}

module sessionStoreRbac './modules/redis-rbac.bicep' = if (deploySessionStore) {
  name: 'sessionStoreRbac'
  scope: rgPlatform
  params: {
    redisName: '${prefix}-redis'
    gatewayPrincipalId: identities.outputs.gatewayPrincipalId
    inferencePrincipalId: identities.outputs.inferencePrincipalId
  }
  dependsOn: [
    sessionStore
  ]
}

module privateDns './modules/private-dns.bicep' = {
  name: 'privateDns'
  scope: rgNetwork
  params: {
    prefix: prefix
    vnetId: network.outputs.vnetId
    deployRedisZone: deploySessionStore
    tags: commonTags
  }
}

module privateEndpoints './modules/private-endpoints.bicep' = {
  name: 'privateEndpoints'
  scope: rgNetwork
  params: {
    prefix: prefix
    location: location
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    keyVaultId: vault.outputs.keyVaultId
    registryId: registry.outputs.registryId
    redisId: deploySessionStore ? sessionStore!.outputs.redisId : ''
    deployRedis: deploySessionStore
    keyVaultPrivateDnsZoneId: privateDns.outputs.keyVaultPrivateDnsZoneId
    registryPrivateDnsZoneId: privateDns.outputs.registryPrivateDnsZoneId
    redisPrivateDnsZoneId: deploySessionStore ? privateDns.outputs.redisPrivateDnsZoneId : ''
    tags: commonTags
  }
}

module rbac './modules/rbac.bicep' = {
  name: 'rbac'
  scope: rgSecurity
  params: {
    keyVaultId: vault.outputs.keyVaultId
    inferencePrincipalId: identities.outputs.inferencePrincipalId
  }
}

module acrRbac './modules/acr-rbac.bicep' = {
  name: 'acrRbac'
  scope: rgPlatform
  params: {
    registryId: registry.outputs.registryId
    acrPullPrincipalId: identities.outputs.acrPullPrincipalId
  }
}

output platformResourceGroup string = rgPlatform.name
output networkResourceGroup string = rgNetwork.name
output securityResourceGroup string = rgSecurity.name
output monitorResourceGroup string = rgMonitor.name
output containerEnvironmentId string = containerEnvironment.outputs.environmentId
output containerEnvironmentName string = containerEnvironment.outputs.environmentName
output registryName string = registry.outputs.registryName
output registryLoginServer string = registry.outputs.loginServer
output keyVaultName string = vault.outputs.keyVaultName
output encryptionKeyName string = vault.outputs.encryptionKeyName
output attestationKeyName string = vault.outputs.attestationKeyName
output gatewayIdentityId string = identities.outputs.gatewayIdentityId
output inferenceIdentityId string = identities.outputs.inferenceIdentityId
output acrPullIdentityId string = identities.outputs.acrPullIdentityId
output redisHost string = deploySessionStore ? sessionStore!.outputs.redisHost : ''
output redisPort int = deploySessionStore ? sessionStore!.outputs.redisPort : 0
output applicationInsightsConnectionString string = monitoring.outputs.applicationInsightsConnectionString
