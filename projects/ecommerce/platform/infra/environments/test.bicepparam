using '../main.bicep'

param workloadName = 'ecommerce'
param environment = 'test'
param primaryLocation = 'eastus2'
param primaryRegionCode = 'eus2'
param secondaryLocation = 'westus2'
param secondaryRegionCode = 'wus2'
param enableSecondaryRegion = false
param frontDoorSkuName = 'Standard_AzureFrontDoor'
param serviceBusSkuName = 'Standard'
param enablePrivateNetworking = false
param cosmosEnableMultipleWriteLocations = false
param cosmosDatabaseThroughput = 1000
param appServicePlanSkuName = 'S1'
param appServicePlanSkuTier = 'Standard'
param dataLakeSkuName = 'Standard_LRS'
param wafMode = 'Detection'
