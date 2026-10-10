param workloadName string
param environment string
param location string
param regionCode string
param suffix string
param appServicePlanSkuName string
param appServicePlanSkuTier string
param appSubnetId string
param frontDoorId string
param applicationInsightsConnectionString string
param cosmosEndpoint string
param cosmosDatabaseName string
param serviceBusFullyQualifiedNamespace string
param keyVaultUri string
param dataLakeAccountName string
param tags object = {}

var planName = 'asp-${workloadName}-${environment}-${regionCode}'
var apiName = 'app-${workloadName}-${environment}-${regionCode}-${suffix}'
var workerNames = [
  'inventory'
  'payment'
  'shipping'
]
var runtimeEnvironment = environment == 'prod' ? 'Production' : environment == 'test' ? 'Staging' : 'Development'

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSkuName
    tier: appServicePlanSkuTier
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
    perSiteScaling: false
    zoneRedundant: false
  }
}

var commonAppSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: applicationInsightsConnectionString
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~3'
  }
  {
    name: 'AZURE_COSMOS_ENDPOINT'
    value: cosmosEndpoint
  }
  {
    name: 'AZURE_COSMOS_DATABASE'
    value: cosmosDatabaseName
  }
  {
    name: 'SERVICEBUS__fullyQualifiedNamespace'
    value: serviceBusFullyQualifiedNamespace
  }
  {
    name: 'KEYVAULT_URI'
    value: keyVaultUri
  }
  {
    name: 'ANALYTICS_STORAGE_ACCOUNT'
    value: dataLakeAccountName
  }
  {
    name: 'REGION'
    value: location
  }
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: runtimeEnvironment
  }
]

resource api 'Microsoft.Web/sites@2025-03-01' = {
  name: apiName
  location: location
  tags: union(tags, {
    component: 'api'
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    virtualNetworkSubnetId: appSubnetId
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: 'DOTNETCORE|8.0'
      minTlsVersion: '1.2'
      healthCheckPath: '/health'
      vnetRouteAllEnabled: true
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: false
      scmIpSecurityRestrictionsDefaultAction: 'Allow'
      ipSecurityRestrictions: [
        {
          ipAddress: 'AzureFrontDoor.Backend'
          tag: 'ServiceTag'
          action: 'Allow'
          priority: 100
          name: 'Allow Azure Front Door'
          headers: {
            'x-azure-fdid': [
              frontDoorId
            ]
          }
        }
      ]
      appSettings: concat(commonAppSettings, [
        {
          name: 'APP_COMPONENT'
          value: 'api'
        }
      ])
    }
  }
}

resource workers 'Microsoft.Web/sites@2025-03-01' = [for workerName in workerNames: {
  name: 'wrk-${workerName}-${environment}-${regionCode}-${suffix}'
  location: location
  tags: union(tags, {
    component: '${workerName}-worker'
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    virtualNetworkSubnetId: appSubnetId
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: 'DOTNETCORE|8.0'
      minTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: false
      scmIpSecurityRestrictionsDefaultAction: 'Allow'
      ipSecurityRestrictions: []
      appSettings: concat(commonAppSettings, [
        {
          name: 'APP_COMPONENT'
          value: '${workerName}-worker'
        }
        {
          name: 'WORKER_ROLE'
          value: workerName
        }
      ])
    }
  }
}]

resource analyticsWorker 'Microsoft.Web/sites@2025-03-01' = {
  name: 'wrk-analytics-${environment}-${regionCode}-${suffix}'
  location: location
  tags: union(tags, {
    component: 'analytics-worker'
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    virtualNetworkSubnetId: appSubnetId
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: 'DOTNETCORE|8.0'
      minTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: false
      scmIpSecurityRestrictionsDefaultAction: 'Allow'
      ipSecurityRestrictions: []
      appSettings: concat(commonAppSettings, [
        {
          name: 'APP_COMPONENT'
          value: 'analytics-worker'
        }
        {
          name: 'WORKER_ROLE'
          value: 'analytics'
        }
      ])
    }
  }
}

output apiName string = api.name
output apiDefaultHostName string = api.properties.defaultHostName
output apiPrincipalId string = api.identity.principalId
output workerPrincipalIds array = [for i in range(0, length(workerNames)): workers[i].identity.principalId]
output paymentPrincipalId string = workers[1].identity.principalId
output analyticsPrincipalId string = analyticsWorker.identity.principalId
output appServicePlanId string = plan.id
