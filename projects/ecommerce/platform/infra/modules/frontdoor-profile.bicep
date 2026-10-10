param profileName string
param endpointName string

@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param skuName string

@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Detection'

param tags object = {}

resource profile 'Microsoft.Cdn/profiles@2025-04-15' = {
  name: profileName
  location: 'global'
  sku: {
    name: skuName
  }
  tags: tags
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-04-15' = {
  name: endpointName
  parent: profile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2025-03-01' = {
  name: 'waf-${profileName}'
  location: 'Global'
  sku: {
    name: skuName
  }
  tags: tags
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
      requestBodyCheck: 'Enabled'
      customBlockResponseStatusCode: 403
    }
    customRules: {
      rules: []
    }
    managedRules: skuName == 'Premium_AzureFrontDoor' ? {
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
    } : {
      managedRuleSets: []
    }
  }
}

output profileName string = profile.name
output profileId string = profile.id
output frontDoorId string = profile.properties.frontDoorId
output endpointName string = endpoint.name
output endpointId string = endpoint.id
output endpointHostName string = endpoint.properties.hostName
output wafPolicyId string = wafPolicy.id
