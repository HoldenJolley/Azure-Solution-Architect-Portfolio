targetScope = 'subscription'

param workloadName string = 'ageverify'

@allowed(['dev', 'test', 'prod'])
param environment string
param location string

@description('Fully qualified gateway container image, ideally immutable/tagged or digest-pinned.')
param gatewayImage string

@description('Fully qualified customer inference/model container image.')
param inferenceImage string

@description('Container port exposed by the gateway image.')
param gatewayPort int = 8080

@description('Container port exposed by the inference image.')
param inferencePort int = 8080

@description('Maximum gateway replicas.')
param gatewayMaxReplicas int = 10

@description('Minimum gateway replicas. Production should generally be >=2.')
param gatewayMinReplicas int = 1

@description('Maximum inference replicas.')
param inferenceMaxReplicas int = 10

@description('Minimum inference replicas. Production should generally be >=2.')
param inferenceMinReplicas int = 1

@description('Assign inference to confidential workload profile.')
param useConfidentialInference bool = false

@description('Deploy session/replay store integration.')
param useSessionStore bool = true

@description('Front Door WAF policy mode.')
@allowed(['Detection', 'Prevention'])
param wafMode string = 'Detection'

@description('Requests per one-minute Front Door WAF rate-limit window for /v1/verify.')
param verificationRateLimit int = 30

param tags object = {}

var prefix = toLower('${workloadName}-${environment}')
var platformRg = '${prefix}-platform-rg'
var securityRg = '${prefix}-security-rg'
var monitorRg = '${prefix}-monitor-rg'
var commonTags = union(tags, {
  workload: workloadName
  environment: environment
  dataClassification: 'highly-sensitive-transient'
  imagePersistence: 'prohibited'
  managedBy: 'bicep'
})

resource rgPlatform 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: platformRg
}
resource rgSecurity 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: securityRg
}
resource rgMonitor 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: monitorRg
}

resource environmentResource 'Microsoft.App/managedEnvironments@2025-07-01' existing = {
  scope: rgPlatform
  name: '${prefix}-cae'
}
resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  scope: rgPlatform
  name: take(replace('${prefix}acr', '-', ''), 50)
}
resource redis 'Microsoft.Cache/redisEnterprise@2025-07-01' existing = if (useSessionStore) {
  scope: rgPlatform
  name: '${prefix}-redis'
}
resource gatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: rgSecurity
  name: '${prefix}-gateway-mi'
}
resource inferenceIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: rgSecurity
  name: '${prefix}-inference-mi'
}
resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: rgSecurity
  name: '${prefix}-acrpull-mi'
}
resource vault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  scope: rgSecurity
  name: take(replace('${prefix}-kv', '-', ''), 24)
}
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  scope: rgMonitor
  name: '${prefix}-appi'
}

module apps './modules/container-apps.bicep' = {
  name: 'containerApps'
  scope: rgPlatform
  params: {
    prefix: prefix
    location: location
    environmentId: environmentResource.id
    gatewayImage: gatewayImage
    inferenceImage: inferenceImage
    gatewayPort: gatewayPort
    inferencePort: inferencePort
    gatewayIdentityId: gatewayIdentity.id
    inferenceIdentityId: inferenceIdentity.id
    acrPullIdentityId: acrPullIdentity.id
    registryServer: registry.properties.loginServer
    keyVaultUri: vault.properties.vaultUri
    encryptionKeyName: 'payload-encryption'
    attestationKeyName: 'decision-attestation'
    applicationInsightsConnectionString: appInsights.properties.ConnectionString
    redisHost: useSessionStore ? '${redis.name}.${location}.redis.azure.net' : ''
    redisPort: useSessionStore ? 10000 : 0
    useSessionStore: useSessionStore
    gatewayMinReplicas: gatewayMinReplicas
    gatewayMaxReplicas: gatewayMaxReplicas
    inferenceMinReplicas: inferenceMinReplicas
    inferenceMaxReplicas: inferenceMaxReplicas
    useConfidentialInference: useConfidentialInference
    tags: commonTags
  }
}

module frontDoor './modules/frontdoor.bicep' = {
  name: 'frontDoor'
  scope: rgPlatform
  params: {
    prefix: prefix
    location: location
    containerEnvironmentId: environmentResource.id
    gatewayFqdn: apps.outputs.gatewayFqdn
    wafMode: wafMode
    verificationRateLimit: verificationRateLimit
    tags: commonTags
  }
}

output frontDoorEndpointHost string = frontDoor.outputs.endpointHost
output gatewayFqdn string = apps.outputs.gatewayFqdn
output inferenceFqdn string = apps.outputs.inferenceFqdn
output privateLinkApprovalRequired bool = true
