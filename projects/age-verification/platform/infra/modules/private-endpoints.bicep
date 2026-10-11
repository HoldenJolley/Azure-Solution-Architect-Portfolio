param prefix string
param location string
param privateEndpointSubnetId string
param keyVaultId string
param registryId string
param redisId string
param deployRedis bool
param keyVaultPrivateDnsZoneId string
param registryPrivateDnsZoneId string
param redisPrivateDnsZoneId string
param tags object

resource kvPe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${prefix}-kv-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'vault'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

resource kvDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: kvPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
}

resource acrPe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${prefix}-acr-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'registry'
        properties: {
          privateLinkServiceId: registryId
          groupIds: [ 'registry' ]
        }
      }
    ]
  }
}

resource acrDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: acrPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'registry'
        properties: {
          privateDnsZoneId: registryPrivateDnsZoneId
        }
      }
    ]
  }
}

resource redisPe 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployRedis) {
  name: '${prefix}-redis-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'redisEnterprise'
        properties: {
          privateLinkServiceId: redisId
          groupIds: [ 'redisEnterprise' ]
        }
      }
    ]
  }
}

resource redisDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployRedis) {
  parent: redisPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'redis'
        properties: {
          privateDnsZoneId: redisPrivateDnsZoneId
        }
      }
    ]
  }
}
