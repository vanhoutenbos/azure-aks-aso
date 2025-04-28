targetScope = 'subscription'

@description('Create a resource group')
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-aso-example-prod-01'
  location: 'westeurope'
}

module aks './aks.bicep' = {
  name: 'aksDeployment'
  scope: rg
  params: {
    rg: rg.name
  }
}
