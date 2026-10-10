param workloadName string
param environment string
param location string
param suffix string
param tags object = {}

var workspaceName = 'log-${workloadName}-${environment}-${suffix}'
var appInsightsName = 'appi-${workloadName}-${environment}-${suffix}'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output logAnalyticsWorkspaceId string = workspace.id
output logAnalyticsWorkspaceName string = workspace.name
output applicationInsightsName string = appInsights.name
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
