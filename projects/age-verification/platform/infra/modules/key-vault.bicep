param prefix string
param location string
param tags object

var vaultName = take(replace('${prefix}-kv', '-', ''), 24)

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'premium'
    }
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}

resource encryptionKey 'Microsoft.KeyVault/vaults/keys@2024-11-01' = {
  parent: vault
  name: 'payload-encryption'
  properties: {
    kty: 'RSA-HSM'
    keySize: 3072
    keyOps: [
      'wrapKey'
      'unwrapKey'
      'encrypt'
      'decrypt'
    ]
    attributes: {
      enabled: true
      exportable: false
    }
  }
}

resource attestationKey 'Microsoft.KeyVault/vaults/keys@2024-11-01' = {
  parent: vault
  name: 'decision-attestation'
  properties: {
    kty: 'RSA-HSM'
    keySize: 3072
    keyOps: [
      'sign'
      'verify'
    ]
    attributes: {
      enabled: true
      exportable: false
    }
  }
}

output keyVaultId string = vault.id
output keyVaultName string = vault.name
output keyVaultUri string = vault.properties.vaultUri
output encryptionKeyName string = encryptionKey.name
output attestationKeyName string = attestationKey.name
