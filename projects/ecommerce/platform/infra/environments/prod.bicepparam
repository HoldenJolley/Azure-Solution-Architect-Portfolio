using '../main.bicep'

param workloadName = 'ecommerce'
param environment = 'prod'
param primaryLocation = 'eastus2'
param primaryRegionCode = 'eus2'
param secondaryLocation = 'westus2'
param secondaryRegionCode = 'wus2'
param enableSecondaryRegion = true
param frontDoorSkuName = 'Premium_AzureFrontDoor'
param serviceBusSkuName = 'Premium'
param enablePrivateNetworking = true
param cosmosEnableMultipleWriteLocations = false
param cosmosDatabaseThroughput = 4000
param appServicePlanSkuName = 'P1v3'
param appServicePlanSkuTier = 'PremiumV3'
param dataLakeSkuName = 'Standard_GZRS'
param wafMode = 'Prevention'
