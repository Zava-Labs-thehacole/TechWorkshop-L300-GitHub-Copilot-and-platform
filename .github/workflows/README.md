# Build & Deploy Workflow

The workflow in `.github/workflows/build-deploy.yml` builds a Docker image, pushes it to Azure Container Registry, and deploys it to App Service on every push to `main` (or via manual dispatch).

## Prerequisites

### 1. Create an Entra ID App Registration with Federated Credentials

```bash
# Create the app registration
az ad app create --display-name "github-deploy-zavastore"

# Note the appId from the output, then create a service principal
az ad sp create --id <APP_ID>

# Grant it Contributor + AcrPush on your resource group
az role assignment create --assignee <APP_ID> --role Contributor --scope /subscriptions/<SUB_ID>/resourceGroups/rg-zava-labs
az role assignment create --assignee <APP_ID> --role AcrPush --scope /subscriptions/<SUB_ID>/resourceGroups/rg-zava-labs

# Add a federated credential for GitHub Actions (replace OWNER/REPO)
az ad app federated-credential create --id <APP_OBJECT_ID> --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:OWNER/TechWorkshop-L300-GitHub-Copilot-and-platform:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### 2. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions → Secrets** and add:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | App registration Application (client) ID |
| `AZURE_TENANT_ID` | Your Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

### 3. Configure GitHub Variables

Go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable | Value |
|---|---|
| `AZURE_ACR_NAME` | Your ACR name (e.g. `acrzavastoreiqxzq7aq4fwu4`) |
| `AZURE_WEBAPP_NAME` | Your App Service name (e.g. `app-zavastore-zava-labs-iqxzq7aq4fwu4`) |

### 4. Run

Push to `main` or trigger manually from the **Actions** tab.
