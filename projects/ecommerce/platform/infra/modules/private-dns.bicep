param vnetIds array
param tags object = {}

var storageDnsSuffix = environment().suffixes.storage

resource cosmosZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: tags
}

resource serviceBusZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  tags: tags
}

resource keyVaultZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource blobZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${storageDnsSuffix}'
  location: 'global'
  tags: tags
}

resource dfsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.dfs.${storageDnsSuffix}'
  location: 'global'
  tags: tags
}

resource cosmosLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (vnetId, index) in vnetIds: {
  name: 'cosmos-link-${index}'
  parent: cosmosZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

resource serviceBusLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (vnetId, index) in vnetIds: {
  name: 'servicebus-link-${index}'
  parent: serviceBusZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

resource keyVaultLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (vnetId, index) in vnetIds: {
  name: 'keyvault-link-${index}'
  parent: keyVaultZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

resource blobLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (vnetId, index) in vnetIds: {
  name: 'blob-link-${index}'
  parent: blobZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

resource dfsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (vnetId, index) in vnetIds: {
  name: 'dfs-link-${index}'
  parent: dfsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

output cosmosPrivateDnsZoneId string = cosmosZone.id
output serviceBusPrivateDnsZoneId string = serviceBusZone.id
output keyVaultPrivateDnsZoneId string = keyVaultZone.id
output blobPrivateDnsZoneId string = blobZone.id
output dfsPrivateDnsZoneId string = dfsZone.id
