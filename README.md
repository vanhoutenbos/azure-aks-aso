# AKS and API Management Infrastructure as Code (IaC)

This project provides an Infrastructure as Code (IaC) solution to deploy an Azure Kubernetes Service (AKS) cluster, API Management (APIM) instance, and a demo API using Azure Service Operator and GitOps with Flux. The setup is designed to follow Azure best practices for security, scalability, and automation.

## Features
- **AKS Cluster**: Deploys an AKS cluster with managed identities, autoscaling, and Azure CNI networking.
- **Azure Service Operator**: Manages Azure resources declaratively within the AKS cluster.
- **API Management**: Creates an APIM instance and a demo API.
- **GitOps with Flux**: Synchronizes configurations from a GitHub repository.
- **Azure Key Vault**: Secures sensitive information like client secrets and tenant IDs.

## Prerequisites
1. An active Azure subscription.
2. Azure CLI installed on your local machine.
3. Git installed on your local machine.
4. A GitHub account to host the repository.

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd aks-apim-iac
```

### 2. Set the Active Azure Subscription
Ensure you are working in the correct Azure subscription:
```bash
az account set --subscription <subscription_id_or_name>
```

### 3. Activate AKS-ExtensionsManager
I couldnt find a way to do this through bicep except some hacky script with `Microsoft.Resources/deploymentScripts@2020-10-01`
So i did it by hand from Powershell

```bash
# Register AKS-ExtensionManager feature
az feature register --namespace Microsoft.ContainerService --name AKS-ExtensionManager

# Register required providers
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.KubernetesConfiguration

# Wait for feature registration to complete (this may take several minutes)
az feature show --namespace Microsoft.ContainerService --name AKS-ExtensionManager --output table
```

### 4. Create a Service Principal
Create a Service Principal to manage Azure resources:
```bash
az ad sp create-for-rbac --name <your-service-principal-name> --role Contributor --scopes /subscriptions/<your-subscription-id> --sdk-auth
```
Copy the output as the whole JSON, which includes the `Client ID`, `Client Secret`, and `Tenant ID`.

#### 4.1 Saving the output in github
If you use github just like me than you need to save the output in github.

1. Go to your GitHub repository (the-stratbook).
1. Navigate to Settings > Secrets and variables > Actions.
1. Click New repository secret.
1. Name the secret AZURE_CREDENTIALS.
1. Paste the entire JSON output from the Azure CLI command into the Secret value box.
1. Click Add secret.
 
### 5. Deploy the Infrastructure
To deploy the infrastructure you can use 2 methods, either you use the deploy.yaml and run it from Github or you run it by hand using the instruction below

#### 5.1 Push to GitHub
Push the repository to GitHub and configure the GitHub Actions workflow:
```bash
git remote add origin <github-repo-url>
git push -u origin main
```

#### 5.2 Manually / locally
Run the following commands to deploy the infrastructure:

```bash
az deployment group create \
  --resource-group <resource_group_name> \
  --template-file infra/main.bicep
```

### 6. Monitor Deployment
The GitHub Actions workflow will automatically deploy the infrastructure and synchronize configurations. Monitor the workflow in the GitHub Actions tab of your repository.

## Project Structure
```
infra/
  main.bicep          # Bicep template for AKS 
manifests/
  apim/
    apim-instance.yaml  # APIM instance manifest
    demo-api.yaml       # Demo API manifest
  operator/
    azure-service-operator.yaml  # Azure Service Operator manifest
```

## Notes
- Replace placeholders like `<spName>`, `<client_id>`, `<client_secret>`, `<tenant_id>`, `<resource_group_name>`, and `<github-repo-url>` with your actual values.
- Ensure you have the necessary permissions to create and manage Azure resources.

## Troubleshooting
- Use `az account show` to verify the active subscription.
- Check the GitHub Actions logs for deployment errors.
- Use `kubectl` to debug issues in the AKS cluster.

## License
This project is licensed under the MIT License.