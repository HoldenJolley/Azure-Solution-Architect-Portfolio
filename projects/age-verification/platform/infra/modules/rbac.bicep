param keyVaultId string
param inferencePrincipalId string

var keyVaultCryptoUserRoleId = '12338af0-0e69-4776-bea7-57ae8d297424'

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: last(split(keyVaultId, '/'))
}

resource inferenceCrypto 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, inferencePrincipalId, keyVaultCryptoUserRoleId)
  scope: vault
  properties: {
    principalId: inferencePrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCryptoUserRoleId)
  }
}
