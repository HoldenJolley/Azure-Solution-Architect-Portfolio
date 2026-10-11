using '../foundation.bicep'

param environment = 'dev'
param location = 'eastus2'
// Keep CI cloud-preflight deterministic: Azure Managed Redis capacity is subscription/region dependent.
// Test/prod profiles retain the session-store architecture; Redis IaC is still lint/build validated.
param deploySessionStore = false
param enableConfidentialCompute = false
param workloadProfileType = 'D4'
param tags = {
  owner: 'HoldenJolley'
  project: 'age-verification-platform'
}
