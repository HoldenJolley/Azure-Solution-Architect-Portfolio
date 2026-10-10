param cosmosAccountName string
param serviceBusNamespaceName string
param keyVaultName string
param dataLakeAccountName string
param apiPrincipalIds array
param workerPrincipalIds array
param analyticsPrincipalIds array
param keyVaultPrincipalIds array

var serviceBusDataSenderRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
var serviceBusDataReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: serviceBusNamespaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource dataLake 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: dataLakeAccountName
}

var cosmosPrincipals = concat(apiPrincipalIds, workerPrincipalIds)
var serviceBusSenderPrincipals = concat(apiPrincipalIds, workerPrincipalIds)
var serviceBusReceiverPrincipals = concat(workerPrincipalIds, analyticsPrincipalIds)

resource cosmosAssignments 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = [for principalId in cosmosPrincipals: {
  name: guid(cosmos.id, principalId, cosmosDataContributorRoleId)
  parent: cosmos
  properties: {
    principalId: principalId
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
    scope: cosmos.id
  }
}]

resource serviceBusSenderAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in serviceBusSenderPrincipals: {
  name: guid(serviceBus.id, principalId, serviceBusDataSenderRoleId)
  scope: serviceBus
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataSenderRoleId)
  }
}]

resource serviceBusReceiverAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in serviceBusReceiverPrincipals: {
  name: guid(serviceBus.id, principalId, serviceBusDataReceiverRoleId)
  scope: serviceBus
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataReceiverRoleId)
  }
}]

resource keyVaultAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}]

resource analyticsStorageAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in analyticsPrincipalIds: {
  name: guid(dataLake.id, principalId, storageBlobDataContributorRoleId)
  scope: dataLake
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
  }
}]
