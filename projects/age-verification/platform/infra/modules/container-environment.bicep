param prefix string
param location string
param infrastructureSubnetId string
param logAnalyticsCustomerId string
@secure()
param logAnalyticsSharedKey string
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
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
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

output environmentId string = env.id
output environmentName string = env.name
output defaultDomain string = env.properties.defaultDomain
