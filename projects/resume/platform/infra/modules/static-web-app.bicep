targetScope = 'resourceGroup'

@description('Azure Static Web Apps resource name.')
param name string

@description('Azure region used for the Static Web Apps resource metadata.')
param location string

param tags object = {}

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: name
  location: location
  tags: tags
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

output name string = staticSite.name
output defaultHostname string = staticSite.properties.defaultHostname
output sku string = staticSite.sku.name
