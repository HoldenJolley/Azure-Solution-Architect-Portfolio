using '../workloads.bicep'

param environment = 'dev'
param location = 'eastus2'
param gatewayImage = 'REPLACE_WITH_GATEWAY_IMAGE'
param inferenceImage = 'REPLACE_WITH_INFERENCE_IMAGE'
param gatewayMinReplicas = 1
param inferenceMinReplicas = 1
param wafMode = 'Detection'
param verificationRateLimit = 30
param useConfidentialInference = false
// Match the dev foundation preflight profile; test/prod retain the managed session store.
param useSessionStore = false
param tags = {
  owner: 'HoldenJolley'
  project: 'age-verification-platform'
}
