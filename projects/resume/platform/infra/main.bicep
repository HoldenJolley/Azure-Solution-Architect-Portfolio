targetScope = 'subscription'

@description('Short workload name used in Azure resource names.')
param workloadName string = 'portfolio'

@description('Azure region used for the Static Web Apps resource metadata.')
param location string = 'eastus2'

@description('Deployment environment. This project intentionally maintains only one Azure production resource; PR environments are managed by Static Web Apps.')
param environment string = 'prod'

param tags object = {}

var prefix = toLower('${workloadName}-${environment}')
var commonTags = union(tags, {
  workload: workloadName
  environment: environment
  architecture: 'static-web-app'
  costProfile: 'free-tier-first'
  managedBy: 'bicep'
})

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-rg'
  location: location
  tags: commonTags
}

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  scope: resourceGroup
  name: '${prefix}-swa'
  location: location
  tags: commonTags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    allowConfigFileUpdates: true
    publicNetworkAccess: 'Enabled'
    stagingEnvironmentPolicy: 'Enabled'
  }
}

output resourceGroupName string = resourceGroup.name
output staticWebAppName string = staticSite.name
output defaultHostname string = staticSite.properties.defaultHostname
output sku string = staticSite.sku.name
