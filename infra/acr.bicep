@description('The name of the Azure Container Registry')
param acrName string

@description('The SKU for the Azure Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSku string = 'Standard'

@description('The Azure region for the resources')
param location string

// Azure Container Registry
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

// Outputs
output acrName string = acrResource.name
output acrLoginServer string = acrResource.properties.loginServer
output acrResourceId string = acrResource.id
