param prefix string
param location string
param containerEnvironmentId string
param gatewayFqdn string
param wafMode string
param verificationRateLimit int
param tags object

resource profile 'Microsoft.Cdn/profiles@2025-04-15' = {
  name: '${prefix}-afd'
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = {
  parent: profile
  name: '${prefix}-endpoint'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2025-06-01' = {
  parent: profile
  name: 'gateway'
  properties: {
    healthProbeSettings: {
      probeIntervalInSeconds: 30
      probePath: '/health'
      probeProtocol: 'Https'
      probeRequestType: 'GET'
    }
    loadBalancingSettings: {
      additionalLatencyInMilliseconds: 50
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    sessionAffinityState: 'Disabled'
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2025-06-01' = {
  parent: originGroup
  name: 'gateway'
  properties: {
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
    hostName: gatewayFqdn
    httpPort: 80
    httpsPort: 443
    originHostHeader: gatewayFqdn
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      groupId: 'managedEnvironments'
      privateLink: {
        id: containerEnvironmentId
      }
      privateLinkLocation: location
      requestMessage: 'Front Door private origin for privacy-preserving age assurance'
      status: 'Pending'
    }
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2025-06-01' = {
  parent: endpoint
  name: 'api'
  properties: {
    enabledState: 'Enabled'
    forwardingProtocol: 'HttpsOnly'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
    originGroup: {
      id: originGroup.id
    }
    patternsToMatch: [ '/*' ]
    supportedProtocols: [ 'Http', 'Https' ]
  }
}

resource waf 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: '${prefix}-waf'
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.2'
          ruleSetAction: 'Block'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleSetAction: 'Block'
        }
      ]
    }
    customRules: {
      rules: [
        {
          name: 'VerificationRateLimit'
          priority: 10
          enabledState: 'Enabled'
          ruleType: 'RateLimitRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: verificationRateLimit
          action: 'Block'
          matchConditions: [
            {
              matchVariable: 'RequestUri'
              operator: 'BeginsWith'
              matchValue: [ '/v1/verify' ]
              transforms: [ 'Lowercase' ]
              negateCondition: false
            }
          ]
        }
      ]
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2025-06-01' = {
  parent: profile
  name: 'waf'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: waf.id
      }
      associations: [
        {
          domains: [
            { id: endpoint.id }
          ]
          patternsToMatch: [ '/*' ]
        }
      ]
    }
  }
}

output endpointHost string = endpoint.properties.hostName
