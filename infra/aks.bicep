resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: 'aks-aso-example-prod-01'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'aks-dns'
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 1
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: false
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
    kubernetesVersion: '1.32.3'
    enableRBAC: true
  }
}

resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  name: 'fluxConfig'
  scope: aksCluster
  properties: {
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: 'https://github.com/vanhoutenbos/azure-aks-aso'
      repositoryRef: {
        branch: 'main'
      }
    }
    kustomizations: {
      operator: {
        path: './manifests/operator'
        prune: true
        wait: true
      }
      apim: {
        path: './manifests/apim'
        prune: true
        wait: true
      }
    }
  }
}
