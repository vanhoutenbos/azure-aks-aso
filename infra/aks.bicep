//TODO: Enable private cluster for better security, but for testing we can start with public access
//@description('User name for the Linux Virtual Machines.')
//param linuxAdminUsername string = 'aksadmin'
//
//@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
//@secure()
//param sshRSAPublicKey string

// Use a valid AKS LTS version
@description('Kubernetes version to use')
param kubernetesVersion string = '1.27.7'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: 'aks-aso-example-prod-01'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'aks-aso-prod-01'
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 1 // TODO: Minimum 2 nodes for production workloads, but for testing we can start with 1 node
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: true
        minCount: 1
        maxCount: 3
        // TODO: Add availability zones for high availability, but for testing we can start with 1 zone
        //availabilityZones: [
        //  '1', '2', '3'
        //]
      }
    ]
    networkProfile: {
      networkPlugin: 'azure' 
      loadBalancerSku: 'standard'
      // Enable network policy for better security
      networkPolicy: 'calico'
    }
    //TODO: Enable private cluster for better security, but for testing we can start with public access
    //linuxProfile: {
    //  adminUsername: linuxAdminUsername
    //  ssh: {
    //    publicKeys: [
    //      {
    //        keyData: sshRSAPublicKey
    //      }
    //    ]
    //  }
    //}
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    // Add Azure AD integration for better authentication
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    // Add Azure Defender for better security
    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: null
        securityMonitoring: {
          enabled: true
        }
      }
    }
  }
}

// Add a delay before deploying Flux to ensure AKS is fully provisioned
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
