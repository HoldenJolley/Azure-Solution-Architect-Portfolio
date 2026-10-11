param redisName string
param gatewayPrincipalId string
param inferencePrincipalId string

resource redis 'Microsoft.Cache/redisEnterprise@2025-07-01' existing = {
  name: redisName
}

resource database 'Microsoft.Cache/redisEnterprise/databases@2025-07-01' existing = {
  parent: redis
  name: 'default'
}

resource gatewayAccess 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-07-01' = {
  parent: database
  name: 'gatewayRuntime'
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: gatewayPrincipalId
    }
  }
}

resource inferenceAccess 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-07-01' = {
  parent: database
  name: 'inferenceRuntime'
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: inferencePrincipalId
    }
  }
}
