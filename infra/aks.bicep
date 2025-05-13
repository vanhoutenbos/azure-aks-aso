// Use a valid AKS LTS version
@description('Kubernetes version to use')
param kubernetesVersion string = '1.27.7'

@description('Environment name (e.g., prod, dev, test)')
param environment string = 'prod'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Cluster name')
param clusterName string = 'aks-aso-example-${environment}-01'

// Generate SSH keys for the cluster if none are provided
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: 'Premium' // Premium tier as specified in the command
  }
  properties: {
    dnsPrefix: 'aks-aso-${environment}-01'
    supportPlan: 'AKSLongTermSupport' // AKS Long-Term Support as specified in the command
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1 // Recommended to have at least 3 nodes for high availability
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure' 
      loadBalancerSku: 'standard'
    }
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
  }
}

resource fluxExtension 'Microsoft.KubernetesConfiguration/extensions@2024-11-01' = {
  name: 'flux'
  scope: aksCluster
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
  }
}

resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  name: 'flux-configuration'
  scope: aksCluster
  dependsOn: [ fluxExtension ]
  properties: {
    scope: 'cluster'
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: 'https://github.com/vanhoutenbos/azure-aks-aso'
      repositoryRef: {
        branch: 'main'
      }
      syncIntervalInSeconds: 300
      timeoutInSeconds: 600
    }
    kustomizations: {
      cert: {
        path: './manifests/cert-manager'
        prune: true
        wait: true
        timeoutInSeconds: 600 
        retryIntervalInSeconds: 60 
      }
      operator: {
        path: './manifests/operator'
        prune: true
        wait: true
        timeoutInSeconds: 600 
        retryIntervalInSeconds: 60
        dependsOn: [
          'cert'
        ]
      }
      rg: {
        path: './manifests/resource-groups' 
        prune: true
        wait: true
        timeoutInSeconds: 600  
        retryIntervalInSeconds: 60
        dependsOn: [
          'operator' 
        ]
      }
      apim: {
        path: './manifests/apim' 
        prune: true
        wait: true
        timeoutInSeconds: 3600  
        retryIntervalInSeconds: 60
        dependsOn: [
          'rg'
        ]
      }
    }
  }
}
