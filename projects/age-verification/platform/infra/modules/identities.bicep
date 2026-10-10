param prefix string
param location string
param tags object

resource gateway 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-gateway-mi'
  location: location
  tags: tags
}

resource inference 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-inference-mi'
  location: location
  tags: tags
}

resource acrPull 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-acrpull-mi'
  location: location
  tags: tags
}

output gatewayIdentityId string = gateway.id
output gatewayPrincipalId string = gateway.properties.principalId
output inferenceIdentityId string = inference.id
output inferencePrincipalId string = inference.properties.principalId
output acrPullIdentityId string = acrPull.id
output acrPullPrincipalId string = acrPull.properties.principalId
