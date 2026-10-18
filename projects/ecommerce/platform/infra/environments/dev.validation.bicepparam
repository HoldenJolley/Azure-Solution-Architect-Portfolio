using '../validation.bicep'

param workloadName = 'ecommerce'
param environment = 'dev'
param primaryLocation = 'eastus2'
param primaryRegionCode = 'eus2'
param serviceBusSkuName = 'Standard'
param enablePrivateNetworking = false
param cosmosDatabaseThroughput = 1000
param appServicePlanSkuName = 'S1'
param appServicePlanSkuTier = 'Standard'
param dataLakeSkuName = 'Standard_LRS'
