param prefix string
param vnetId string
param deployRedisZone bool
param tags object

resource keyVaultZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource acrZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

resource redisZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployRedisZone) {
  name: 'privatelink.redis.azure.net'
  location: 'global'
  tags: tags
}

resource kvLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: keyVaultZone
  name: '${prefix}-kv-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource acrLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: acrZone
  name: '${prefix}-acr-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource redisLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployRedisZone) {
  parent: redisZone
  name: '${prefix}-redis-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output keyVaultPrivateDnsZoneId string = keyVaultZone.id
output registryPrivateDnsZoneId string = acrZone.id
output redisPrivateDnsZoneId string = deployRedisZone ? redisZone.id : ''
