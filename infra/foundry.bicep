@description('The name of the Azure AI Foundry (AI Services / Cognitive Services) resource')
param foundryName string

@description('The Azure region for the resources')
param location string

// Azure AI Foundry (Azure AI Services hub)
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: foundryName
  location: location
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Azure AI Foundry hub for ZavaStorefront AI capabilities'
    friendlyName: foundryName
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

// Azure AI Services (Cognitive Services) for model access
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: '${foundryName}-ai'
  location: location
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: '${foundryName}-ai'
  }
}

// GPT-4 model deployment
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: aiServices
  name: 'gpt-4'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4'
      version: '0613'
    }
  }
}

// Phi-3 model deployment
resource phi3Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: aiServices
  name: 'Phi-3'
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'Microsoft'
      name: 'Phi-3-mini-128k-instruct'
      version: '14'
    }
  }
  dependsOn: [gpt4Deployment]
}

// Outputs
output foundryName string = aiHub.name
output aiServicesName string = aiServices.name
output aiServicesEndpoint string = aiServices.properties.endpoint
output gpt4DeploymentName string = gpt4Deployment.name
output phi3DeploymentName string = phi3Deployment.name
