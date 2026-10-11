param prefix string
param location string
param environmentId string
param gatewayImage string
param inferenceImage string
param gatewayPort int
param inferencePort int
param gatewayIdentityId string
param inferenceIdentityId string
param acrPullIdentityId string
param registryServer string
param keyVaultUri string
param encryptionKeyName string
param attestationKeyName string
param applicationInsightsConnectionString string
param redisHost string
param redisPort int
param useSessionStore bool
param gatewayMinReplicas int
param gatewayMaxReplicas int
param inferenceMinReplicas int
param inferenceMaxReplicas int
param useConfidentialInference bool
param tags object

resource inference 'Microsoft.App/containerApps@2025-07-01' = {
  name: '${prefix}-inference'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${inferenceIdentityId}': {}
      '${acrPullIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    workloadProfileName: useConfidentialInference ? 'confidential' : 'standard'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        allowInsecure: false
        targetPort: inferencePort
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: registryServer
          identity: acrPullIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'inference'
          image: inferenceImage
          env: [
            { name: 'KEY_VAULT_URI', value: keyVaultUri }
            { name: 'PAYLOAD_ENCRYPTION_KEY_NAME', value: encryptionKeyName }
            { name: 'ATTESTATION_KEY_NAME', value: attestationKeyName }
            { name: 'AZURE_CLIENT_ID', value: reference(inferenceIdentityId, '2023-01-31').clientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: applicationInsightsConnectionString }
            { name: 'PRIVACY_LOG_REQUEST_BODY', value: 'false' }
            { name: 'PRIVACY_LOG_RESPONSE_BODY', value: 'false' }
            { name: 'PRIVACY_PERSIST_IMAGE', value: 'false' }
            { name: 'SESSION_STORE_ENABLED', value: useSessionStore ? 'true' : 'false' }
            { name: 'REDIS_HOST', value: redisHost }
            { name: 'REDIS_PORT', value: string(redisPort) }
          ]
          resources: {
            cpu: json('2.0')
            memory: '4Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/health', port: inferencePort, scheme: 'HTTP' }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: { path: '/ready', port: inferencePort, scheme: 'HTTP' }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: inferenceMinReplicas
        maxReplicas: inferenceMaxReplicas
        rules: [
          {
            name: 'http'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

resource gateway 'Microsoft.App/containerApps@2025-07-01' = {
  name: '${prefix}-gateway'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${gatewayIdentityId}': {}
      '${acrPullIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    workloadProfileName: 'standard'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        allowInsecure: false
        targetPort: gatewayPort
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: registryServer
          identity: acrPullIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'gateway'
          image: gatewayImage
          env: [
            { name: 'INFERENCE_BASE_URL', value: 'https://${inference.properties.configuration.ingress.fqdn}' }
            { name: 'AZURE_CLIENT_ID', value: reference(gatewayIdentityId, '2023-01-31').clientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: applicationInsightsConnectionString }
            { name: 'PRIVACY_LOG_REQUEST_BODY', value: 'false' }
            { name: 'PRIVACY_LOG_RESPONSE_BODY', value: 'false' }
            { name: 'PRIVACY_PERSIST_IMAGE', value: 'false' }
            { name: 'SESSION_STORE_ENABLED', value: useSessionStore ? 'true' : 'false' }
            { name: 'REDIS_HOST', value: redisHost }
            { name: 'REDIS_PORT', value: string(redisPort) }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/health', port: gatewayPort, scheme: 'HTTP' }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: { path: '/ready', port: gatewayPort, scheme: 'HTTP' }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: gatewayMinReplicas
        maxReplicas: gatewayMaxReplicas
        rules: [
          {
            name: 'http'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

output gatewayFqdn string = gateway.properties.configuration.ingress.fqdn
output inferenceFqdn string = inference.properties.configuration.ingress.fqdn
