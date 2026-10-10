param profileName string
param endpointName string
param wafPolicyId string

@description('Origin definitions. hostName must be a DNS name without scheme or path.')
param origins array

resource profile 'Microsoft.Cdn/profiles@2025-04-15' existing = {
  name: profileName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-04-15' existing = {
  name: endpointName
  parent: profile
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2025-04-15' = {
  name: 'api-origin-group'
  parent: profile
  properties: {
    sessionAffinityState: 'Disabled'
    healthProbeSettings: {
      probePath: '/health'
      probeProtocol: 'Https'
      probeRequestType: 'GET'
      probeIntervalInSeconds: 60
    }
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
  }
}

resource originResources 'Microsoft.Cdn/profiles/originGroups/origins@2025-04-15' = [for origin in origins: {
  name: origin.name
  parent: originGroup
  properties: {
    hostName: origin.hostName
    originHostHeader: origin.hostName
    httpPort: 80
    httpsPort: 443
    priority: origin.priority
    weight: origin.weight
    enabledState: origin.enabled ? 'Enabled' : 'Disabled'
    enforceCertificateNameCheck: true
  }
}]

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2025-04-15' = {
  name: 'api-route'
  parent: endpoint
  dependsOn: [
    originResources
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2025-04-15' = {
  name: 'default-waf-policy'
  parent: profile
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicyId
      }
      associations: [
        {
          domains: [
            {
              id: endpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

output routeId string = route.id
