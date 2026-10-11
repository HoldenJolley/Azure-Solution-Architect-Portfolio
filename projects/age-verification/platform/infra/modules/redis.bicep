param prefix string
param location string
param skuName string
param tags object

resource redis 'Microsoft.Cache/redisEnterprise@2025-07-01' = {
  name: '${prefix}-redis'
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    encryption: {}
    highAvailability: 'Enabled'
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

resource database 'Microsoft.Cache/redisEnterprise/databases@2025-07-01' = {
  parent: redis
  name: 'default'
  properties: {
    accessKeysAuthentication: 'Disabled'
    clientProtocol: 'Encrypted'
    clusteringPolicy: 'OSSCluster'
    evictionPolicy: 'VolatileLRU'
    modules: []
    port: 10000
  }
}

output redisId string = redis.id
output redisHost string = '${redis.name}.${location}.redis.azure.net'
output redisPort int = 10000
