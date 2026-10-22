@description('Workload name.')
param workloadName string

@description('Environment name.')
param environment string

@description('Azure region.')
param location string

@description('Short region code.')
param regionCode string

@description('VNet address space.')
param addressSpace string

@description('Subnet delegated to App Service regional VNet integration.')
param appSubnetPrefix string

@description('Subnet used by private endpoints.')
param privateEndpointSubnetPrefix string

param tags object = {}

var vnetName = 'vnet-${workloadName}-${environment}-${regionCode}'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
  }
}

resource appSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'snet-app'
  parent: vnet
  properties: {
    addressPrefix: appSubnetPrefix
    delegations: [
      {
        name: 'app-service-delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'snet-private-endpoints'
  parent: vnet
  properties: {
    addressPrefix: privateEndpointSubnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    appSubnet
  ]
}

output vnetId string = vnet.id
output appSubnetId string = appSubnet.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
