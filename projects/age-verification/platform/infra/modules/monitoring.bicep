param prefix string
param location string
param environment string
param tags object

var retentionDays = environment == 'prod' ? 90 : 30

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-law'
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-appi'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    DisableLocalAuth: true
    RetentionInDays: retentionDays
  }
}

output workspaceId string = workspace.id
output logAnalyticsCustomerId string = workspace.properties.customerId
output logAnalyticsSharedKey string = listKeys(workspace.id, '2023-09-01').primarySharedKey
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
