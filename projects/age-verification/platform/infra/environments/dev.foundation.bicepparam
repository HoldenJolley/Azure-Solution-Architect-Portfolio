using '../foundation.bicep'

param environment = 'dev'
param location = 'eastus'
param deploySessionStore = true
param enableConfidentialCompute = false
param workloadProfileType = 'D4'
param redisSku = 'Balanced_B1'
param tags = {
  owner: 'HoldenJolley'
  project: 'age-verification-platform'
}
