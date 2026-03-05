# ZavaStorefront Azure Infrastructure

This directory contains the Azure infrastructure-as-code (IaC) for the ZavaStorefront web application, built using Azure Developer CLI (AZD) and Bicep templates.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Resource Group: rg-zavastorefront-dev  (westus3)           │
│                                                              │
│  ┌────────────────┐    ┌──────────────────────────────┐    │
│  │  App Service   │───▶│  Azure Container Registry    │    │
│  │  (Linux)       │    │  (ACR)                        │    │
│  │                │    │  AcrPull via Managed Identity │    │
│  └────────────────┘    └──────────────────────────────┘    │
│          │                                                   │
│          ▼                                                   │
│  ┌────────────────┐    ┌──────────────────────────────┐    │
│  │  Application   │    │  Azure AI Foundry            │    │
│  │  Insights      │    │  (GPT-4 + Phi-3)             │    │
│  └────────────────┘    └──────────────────────────────┘    │
│          │                                                   │
│          ▼                                                   │
│  ┌────────────────┐                                         │
│  │  Log Analytics │                                         │
│  │  Workspace     │                                         │
│  └────────────────┘                                         │
└─────────────────────────────────────────────────────────────┘
```

## Resources Provisioned

| Resource | Name | SKU / Tier |
|---|---|---|
| Resource Group | `rg-zavastorefront-dev` | — |
| App Service Plan | `asp-zavastorefront-dev` | B1 (Linux) |
| App Service | `app-zavastorefront-dev` | — |
| Azure Container Registry | `acrzavastorefront{env}` | Standard |
| Application Insights | `appi-zavastorefront-dev` | — |
| Log Analytics Workspace | `log-zavastorefront-dev` | PerGB2018 |
| Azure AI Foundry | `foundry-zavastorefront-dev` | Basic |
| AI Services (Cognitive) | `foundry-zavastorefront-dev-ai` | S0 |
| Managed Identity | `mi-zavastorefront-dev` | — |

## Templates

| File | Purpose |
|---|---|
| `main.bicep` | Root orchestration template |
| `app-service.bicep` | App Service Plan + App Service + Managed Identity |
| `acr.bicep` | Azure Container Registry |
| `acr-role.bicep` | AcrPull RBAC role assignment |
| `app-insights.bicep` | Application Insights + Log Analytics |
| `foundry.bicep` | Azure AI Foundry + GPT-4 + Phi-3 deployments |
| `main.parameters.json` | Default parameter values (dev environment) |

## Prerequisites

1. **Azure CLI** - [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Azure Developer CLI (AZD)** - [Install](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
3. **Azure subscription** with the following permissions:
   - Contributor role on the subscription
   - Ability to create role assignments (to configure RBAC for ACR)
4. Login to Azure:
   ```bash
   az login
   azd auth login
   ```

## Deployment

### Quick Start

```bash
# 1. Clone the repository and navigate to it
cd <repo-root>

# 2. Initialize AZD (only needed once)
azd init

# 3. Preview the infrastructure (optional but recommended)
azd provision --preview

# 4. Provision all infrastructure resources
azd provision

# 5. Build and deploy the application
azd deploy

# 6. Monitor the application
azd monitor
```

### Step-by-Step Deployment Guide

#### Step 1: Initialize AZD

```bash
azd init
```

- Select **Use code in the current directory**
- AZD will detect the .NET application in `src/`
- Confirm the port configuration

#### Step 2: Preview Infrastructure

```bash
azd provision --preview
```

Review the resources that will be created before committing.

#### Step 3: Provision Resources

```bash
azd provision
```

You will be prompted for:
- **Environment name**: A unique name for your environment (e.g., `dev`)
- **Azure subscription**: Select your subscription
- **Location**: Defaults to `westus3`

All resources will be created in the `rg-zavastorefront-dev` resource group in the `westus3` region.

#### Step 4: Build and Push Container Image

After provisioning, build and push the container image to ACR:

```bash
# Get the ACR name from AZD outputs
ACR_NAME=$(azd env get-value AZURE_CONTAINER_REGISTRY_NAME)

# Build the Docker image using ACR Tasks (no local Docker required)
az acr build \
  --registry $ACR_NAME \
  --image zavastorefront:latest \
  --file src/Dockerfile \
  src/
```

#### Step 5: Deploy the Application

```bash
azd deploy
```

#### Step 6: Verify Deployment

```bash
# Open the application in a browser
azd show

# View Application Insights data
azd monitor
```

## Azure RBAC Configuration (Secure Image Pulls)

The App Service uses Azure Managed Identity to pull container images from ACR **without any passwords or connection strings**.

### How It Works

1. A **User-Assigned Managed Identity** (`mi-zavastorefront-dev`) is created
2. The Managed Identity is assigned the **AcrPull** role on the Container Registry
3. The App Service is configured with `acrUseManagedIdentityCreds: true`
4. Azure AD handles authentication automatically — no credentials stored anywhere

### Benefits

- No passwords or secrets in application settings
- Automatic token refresh and management
- Full audit trail of image pull operations
- Easy to rotate/revoke access without updating app settings

### Role Assignment Details

```bicep
// AcrPull Role ID: 7f951dda-4ed3-4680-a7ca-43fe172d538d
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
```

## Environment Configuration

Parameters are controlled through `main.parameters.json`. You can override values for different environments:

| Parameter | Default | Description |
|---|---|---|
| `environment` | `dev` | Environment name suffix |
| `applicationName` | `zavastorefront` | Application name for resource naming |
| `location` | `westus3` | Azure region |
| `appServiceSkuName` | `B1` | App Service Plan SKU |
| `appServiceSkuCapacity` | `1` | App Service Plan instance count |
| `acrSku` | `Standard` | Container Registry SKU |

## Post-Deployment Verification

```bash
# Check all resources in the resource group
az resource list --resource-group rg-zavastorefront-dev --output table

# Test the application endpoint
APP_URL=$(azd env get-value AZURE_APP_SERVICE_URL)
curl -I $APP_URL

# Check Application Insights for telemetry
az monitor app-insights component show \
  --app appi-zavastorefront-dev \
  --resource-group rg-zavastorefront-dev
```

## Monitoring and Troubleshooting

### View Application Logs

```bash
az webapp log tail \
  --name app-zavastorefront-dev \
  --resource-group rg-zavastorefront-dev
```

### Application Insights

Navigate to the Azure Portal and open **Application Insights** (`appi-zavastorefront-dev`) to view:
- Live metrics
- Request traces
- Exceptions and failures
- Performance data

### Common Issues

| Issue | Solution |
|---|---|
| Image pull fails | Verify AcrPull role assignment exists on ACR |
| App Service 503 | Check container logs: `az webapp log tail` |
| Foundry model unavailable | Confirm westus3 region supports the model |

## CI/CD Integration

See `.github/workflows/deploy.yml` for the GitHub Actions workflow that automates:
1. Building the container image using ACR Tasks
2. Deploying to App Service via AZD

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Azure service principal JSON |

### Required GitHub Variables

| Variable | Description |
|---|---|
| `AZURE_CONTAINER_REGISTRY_NAME` | ACR name (without `.azurecr.io`) |
| `AZURE_APP_SERVICE_NAME` | App Service name |

## Cost Optimization

For development environments, the default configuration uses minimal-cost SKUs:
- **App Service Plan B1**: ~$13/month
- **Container Registry Standard**: ~$20/month
- **Log Analytics**: Pay-per-GB ingested
- **Application Insights**: First 5 GB/month free

To further reduce costs, scale down when not in use:
```bash
az appservice plan update \
  --name asp-zavastorefront-dev \
  --resource-group rg-zavastorefront-dev \
  --sku FREE
```

## Cleanup

To remove all resources:
```bash
azd down --purge
```

This deletes the resource group and all contained resources.
