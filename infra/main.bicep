targetScope = 'subscription'

@description('The environment name (e.g. dev, staging, prod)')
param environment string = 'dev'

@description('The application name used in resource naming')
param applicationName string = 'zavastorefront'

@description('The Azure region for all resources')
param location string = 'westus3'

@description('The SKU name for the App Service Plan')
param appServiceSkuName string = 'B1'

@description('The capacity for the App Service Plan')
param appServiceSkuCapacity int = 1

@description('The SKU for the Azure Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSku string = 'Standard'

// Derived resource names
var resourceGroupName = 'rg-${applicationName}-${environment}'
var appServicePlanName = 'asp-${applicationName}-${environment}'
var appServiceName = 'app-${applicationName}-${environment}'
var acrName = 'acr${applicationName}${environment}'
var appInsightsName = 'appi-${applicationName}-${environment}'
var logAnalyticsName = 'log-${applicationName}-${environment}'
var foundryName = 'foundry-${applicationName}-${environment}'
var managedIdentityName = 'mi-${applicationName}-${environment}'

// Create the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

// Deploy Application Insights and Log Analytics
module appInsights 'app-insights.bicep' = {
  name: 'appInsightsDeploy'
  scope: rg
  params: {
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    location: location
  }
}

// Deploy Azure Container Registry
module acr 'acr.bicep' = {
  name: 'acrDeploy'
  scope: rg
  params: {
    acrName: acrName
    acrSku: acrSku
    location: location
  }
}

// Deploy App Service (depends on ACR and App Insights for configuration)
module appService 'app-service.bicep' = {
  name: 'appServiceDeploy'
  scope: rg
  params: {
    appServicePlanName: appServicePlanName
    appServiceName: appServiceName
    managedIdentityName: managedIdentityName
    location: location
    skuName: appServiceSkuName
    skuCapacity: appServiceSkuCapacity
    acrLoginServer: acr.outputs.acrLoginServer
    appInsightsConnectionString: appInsights.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: appInsights.outputs.appInsightsInstrumentationKey
    logAnalyticsWorkspaceId: appInsights.outputs.logAnalyticsWorkspaceId
  }
}

// Grant AcrPull role to the App Service Managed Identity (after both ACR and App Service exist)
module acrRoleAssignment 'acr-role.bicep' = {
  name: 'acrRoleAssignmentDeploy'
  scope: rg
  params: {
    acrName: acrName
    principalId: appService.outputs.principalId
  }

}

// Deploy Azure AI Foundry
module foundry 'foundry.bicep' = {
  name: 'foundryDeploy'
  scope: rg
  params: {
    foundryName: foundryName
    location: location
  }
}

// Outputs
output resourceGroupName string = rg.name
output appServiceName string = appService.outputs.appServiceName
output appServiceUrl string = appService.outputs.appServiceUrl
output acrLoginServer string = acr.outputs.acrLoginServer
output appInsightsName string = appInsights.outputs.appInsightsName
output foundryName string = foundryName
