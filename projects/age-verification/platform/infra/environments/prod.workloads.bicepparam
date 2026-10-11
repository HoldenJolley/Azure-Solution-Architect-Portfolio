using '../workloads.bicep'

param environment = 'prod'
param location = 'eastus2'
param gatewayImage = 'REPLACE_WITH_GATEWAY_IMAGE'
param inferenceImage = 'REPLACE_WITH_INFERENCE_IMAGE'
param gatewayMinReplicas = 2
param inferenceMinReplicas = 2
param wafMode = 'Prevention'
param verificationRateLimit = 15
param useConfidentialInference = false
param tags = {
  owner: 'HoldenJolley'
  project: 'age-verification-platform'
}
