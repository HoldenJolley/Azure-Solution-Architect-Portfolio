using '../main.bicep'

param workloadName = 'portfolio'
param environment = 'prod'
param location = 'eastus2'
param tags = {
  owner: 'HoldenJolley'
  project: 'azure-solution-architect-portfolio'
  purpose: 'portfolio-hosting'
}
