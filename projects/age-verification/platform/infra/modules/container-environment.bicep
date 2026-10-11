param prefix string
param location string
param infrastructureSubnetId string
param logAnalyticsWorkspaceId string
param workloadProfileType string
param enableConfidentialCompute bool
param confidentialWorkloadProfileType string
param tags object

var workloadProfiles = enableConfidentialCompute ? [
  {
    name: 'standard'
    workloadProfileType: workloadProfileType
    minimumCount: 2
    maximumCount: 10
  }
  {
    name: 'confidential'
    workloadProfileType: confidentialWorkloadProfileType
    minimumCount: 1
    maximumCount: 5
  }
] : [
  {
    name: 'standard'
    workloadProfileType: workloadProfileType
    minimumCount: 2
    maximumCount: 10
  }
]

resource env 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: '${prefix}-cae'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    peerAuthentication: {
      mtls: {
        enabled: true
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: true
      }
    }
    publicNetworkAccess: 'Disabled'
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: true
    }
    workloadProfiles: workloadProfiles
    zoneRedundant: true
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${prefix}-environment-diagnostics'
  scope: env
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output environmentId string = env.id
output environmentName string = env.name
output defaultDomain string = env.properties.defaultDomain
