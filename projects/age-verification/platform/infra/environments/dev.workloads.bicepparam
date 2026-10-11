using '../workloads.bicep'

param environment = 'dev'
param location = 'eastus'
param gatewayImage = 'REPLACE_WITH_GATEWAY_IMAGE'
param inferenceImage = 'REPLACE_WITH_INFERENCE_IMAGE'
param gatewayMinReplicas = 1
param inferenceMinReplicas = 1
param wafMode = 'Detection'
param verificationRateLimit = 30
param useConfidentialInference = false
param tags = {
  owner: 'HoldenJolley'
  project: 'age-verification-platform'
}
