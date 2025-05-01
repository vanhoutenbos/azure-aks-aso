# AKS and API Management Infrastructure as Code (IaC)

This project provides an Infrastructure as Code (IaC) solution to deploy an Azure Kubernetes Service (AKS) cluster, API Management (APIM) instance, and a demo API using Azure Service Operator and GitOps with Flux. The setup is designed to follow Azure best practices for security, scalability, and automation.

## Features
- **AKS Cluster**: Deploys an AKS cluster with managed identities, autoscaling, and Azure CNI networking.
- **Azure Service Operator**: Manages Azure resources declaratively within the AKS cluster.
- **API Management**: Creates an APIM instance and a demo API.
- **GitOps with Flux**: Synchronizes configurations from a GitHub repository.

## Prerequisites
1. An active Azure subscription.
2. Azure CLI installed on your local machine.
3. Git installed on your local machine.
4. A GitHub account to host the repository.

## Motivation

I have created this project to explore the Azure Service Operator (ASO) and see what the use-cases are to implement this tool.
Whilst also keeping in mind Best Practices which you can find below.

### Best Practises

| Best Practice | Status | Notes |
|---------------|--------|-------|
| **Least Privilege**      | ✅/⚠️ | Bicep itself doesn't assign excessive permissions, but make sure the deployment identity has only required roles (e.g., `Contributor` on the resource group, `Kubernetes Cluster - Azure Arc Onboarding` for Flux). |
| **Idempotence**          | ✅ | Bicep is declarative. Redeploying will not create duplicates or errors on existing resources (as long as resource names match). |
| **Identity**             | ✅ | Use of system-assigned **managed identity** for AKS and extensions       |
| **GitOps**               | ✅ | Using **Flux v2 extension** natively for GitOps                          |
| **Security**             | ✅ | SSH key authentication (no passwords)                                    |
| **Resource Registration**| ✅ | CLI script includes `--wait` to handle async provider registration       |
| **Modular Parameters**   | ✅ | Use of parameters for Git repo, SSH key, and paths                       |
| **Flux Kustomization**   | ✅ | GitOps configured with `prune`, sync intervals, and scoped paths         |
| **Auto-upgrades**        | ✅ | Flux extension uses `autoUpgradeMinorVersion: true`                      |
| **Config drift**         | ✅ | Bicep and ASO together with FLUX will make sure that there will not be any configuration drift between the config & the actual deployment, you can even set azure to 'read-only' |

### Production Ready

The example used is **NOT** production ready, there are some things that you will need to consider which will be explained below!
The example is purely as a **Proof Of Concept** to address my motivation, but I will give some tips how to make it production ready!

#### Networking

For networking I now use the default that Microsoft provides but for security reasons like pod-level isolation you should consider using [Azure Network Policies](https://learn.microsoft.com/en-us/azure/aks/use-network-policies) or [Calico](https://learn.microsoft.com/en-us/azure/aks/use-network-policies#using-calico-network-policy).

#### Private Clusters

For production workload you should use [private AKS clusters](https://learn.microsoft.com/en-us/azure/aks/private-clusters), this way you prevent that you expose the Kubernetes API Server publicly 

#### Disable local admin

For security and audit reasons you should always disable the Local Admin on your kubernetes cluster and force AAD-based authentication

#### Key Vault

You should add a keyvault to store your flux secrets and potentially other passwords or credentials so that they are no available in your source code.


#### Resource Locks

To prevent accidental deletion you should consider adding resource locks to all resources or at least the one that are statefull or cannot be offline for a short period of time.

#### Availability Zones

Based on your requirements and SLA needs you should add 3 availability zones to increase resilience.

You can do this by setting the following value in the `agentpoolprofile`;
```bicep
availabilityZones: [
  '1', '2', '3'
]
```

#### Log Analytics

Enable [Azure Monitor for containers](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview) for observability.

#### Policy as Code

Consider integrating [Azure Policy for Kubernetes](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes).

#### Health Probes

Set up alerts for Flux sync failures or AKS node health.

#### Backup and Restore

Implement a strategy using tools like Velero to back up cluster state and PVs.

#### Autoscaling

Add autoscaling to your cluster to prevent you to overspend on resources that are not being utilized.

You can do this by setting the following value in the `agentpoolprofile`;
```bicep
enableAutoScaling: true
minCount: 1
maxCount: 3
```

#### Upgrade Settings

For production based environments it is always good to keep atleast 2/3 of your environment up and running while upgrades are being done.

You can do this by setting the following value in the `agentpoolprofile`;
```bicep
upgradeSettings: {
  maxSurge: '33%'
}
```

### Auto-update

You can automatically update your AKS cluster and nodepools when a new version releases (either LTS or none LTS).

You can do this by setting the following value in the `properties`;
```bicep
autoUpgradeProfile: {
  upgradeChannel: 'stable'
}
```

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd azure-aks-aso
```

### 2. Set the Active Azure Subscription
Ensure you are working in the correct Azure subscription:
```bash
az account set --subscription <subscription_id_or_name>
```

### 3. Create a Service Principal
Create a Service Principal to manage Azure resources:
```bash
az ad sp create-for-rbac --name <your-service-principal-name> --role Contributor --scopes /subscriptions/<your-subscription-id> --sdk-auth
```
Copy the output as the whole JSON, which includes the `Client ID`, `Client Secret`, and `Tenant ID`.

#### 3.1 Saving the output in github
If you use github just like me than you need to save the output in github.

1. Go to your GitHub repository (the-stratbook).
1. Navigate to Settings > Secrets and variables > Actions.
1. Click New repository secret.
1. Name the secret AZURE_CREDENTIALS.
1. Paste the entire JSON output from the Azure CLI command into the Secret value box.
1. Click Add secret.
 
### 4. Deploy the Infrastructure
To deploy the infrastructure you can use 2 methods, either you use the deploy.yaml and run it from Github or you run it by hand using the instruction below

#### 4.1 Push to GitHub
Push the repository to GitHub and configure the GitHub Actions workflow:
```bash
git remote add origin <github-repo-url>
git push -u origin main
```

#### 4.2 Manually / locally
Run the following commands to deploy the infrastructure:

```bash
az deployment group create \
  --resource-group <resource_group_name> \
  --template-file infra/main.bicep
```

### 5. Monitor Deployment
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