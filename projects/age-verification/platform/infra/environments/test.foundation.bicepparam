using '../foundation.bicep'

param environment = 'test'
param location = 'eastus2'
param deploySessionStore = true
param enableConfidentialCompute = false
param workloadProfileType = 'D4'
param tags = {
  owner: 'HoldenJolley'
  project: 'age-verification-platform'
}
