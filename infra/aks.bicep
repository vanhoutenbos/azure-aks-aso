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
        name: 'nodepool1'
        count: 1 // Recommended to have at least 3 nodes for high availability
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: true
        minCount: 1
        maxCount: 3
        // TODO apply Best practice: Use availability zones for production workloads
        //availabilityZones: [
        //  '1', '2', '3'
        //]
        upgradeSettings: {
          maxSurge: '33%' // Best practice for node upgrades
        }
      }
    ]
    networkProfile: {
      networkPlugin: 'azure' 
      loadBalancerSku: 'standard'
      networkPolicy: 'calico' // Best practice: Enable network policy
    }
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    // Best practice: Enable Azure AD integration
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    // Best practice: Enable Azure Defender for security
    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: null
        securityMonitoring: {
          enabled: true
        }
      }
    }
    // Best practice: Enable auto-upgrade channel
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    // Best practice: Enable monitoring
    addonProfiles: {
      omsagent: {
        enabled: true
      }
    }
  }
}

// Add Flux configuration
resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  name: 'flux-configuration'
  scope: aksCluster
  properties: {
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: 'https://github.com/vanhoutenbos/azure-aks-aso'
      repositoryRef: {
        branch: 'main'
      }
      syncIntervalInSeconds: 300 // 5 minutes sync interval
      timeoutInSeconds: 600 // 10 minutes timeout
    }
    kustomizations: {
      operator: {
        path: './manifests/operator'
        prune: true
        wait: true
        timeoutInSeconds: 600 // 10 minutes timeout
        retryIntervalInSeconds: 60 // 1 minute retry interval
      }
      apim: {
        path: './manifests/apim'
        prune: true
        wait: true
        timeoutInSeconds: 600
        retryIntervalInSeconds: 60
        dependsOn: [
          'operator'
        ]
      }
    }
  }
}

output aksClusterName string = aksCluster.name
output aksClusterId string = aksCluster.id
