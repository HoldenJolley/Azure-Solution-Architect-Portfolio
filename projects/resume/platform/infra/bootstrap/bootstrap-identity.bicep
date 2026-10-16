targetScope = 'subscription'

param location string = 'eastus2'
param resourceGroupName string = 'portfolio-bootstrap-rg'
param identityName string = 'github-portfolio-prod-mi'
param federatedCredentialName string = 'github-prod'
param githubSubject string
param tags object = {
  owner: 'HoldenJolley'
  project: 'azure-solution-architect-portfolio'
  purpose: 'deployment-identity'
}

var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource bootstrapResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module deploymentIdentity './deployment-identity.bicep' = {
  name: 'portfolioDeploymentIdentity'
  scope: bootstrapResourceGroup
  params: {
    location: location
    identityName: identityName
    federatedCredentialName: federatedCredentialName
    githubSubject: githubSubject
    tags: tags
  }
}

resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, identityName, contributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: deploymentIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

output clientId string = deploymentIdentity.outputs.clientId
output principalId string = deploymentIdentity.outputs.principalId
output identityResourceId string = deploymentIdentity.outputs.resourceId
