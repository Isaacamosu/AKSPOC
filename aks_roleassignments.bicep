param acrRole string
param principalId string  // this will come from aks output in main.bicep
param acr_name string
param runcmdRole string
param aks_name string
param aksrbacRole string
param keyVaultName string
param spn string

param kvsecrole string

resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' existing = {
  name: acr_name
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' existing = {
  name: aks_name
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

//resource keyVaultCSIdriverSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  //scope: keyVault
  //name: guid(aks_name, 'CSIDriver', kvsecrole)
  //properties: {
    //roleDefinitionId: kvsecrole
    //principalType: ServicePrincipal
    //principalId: principalId
  //}
//}


resource aksRbacPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = { 
  name: guid(resourceGroup().id)
  properties: {
    principalId: spn
    roleDefinitionId: aksrbacRole
  }
}

resource aksAcrPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = { 
  name: guid(resourceGroup().id)
  scope: acr
  properties: {
    principalId: principalId
    roleDefinitionId: acrRole
  }
}


resource spRunCommandPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = { 
  name: guid(resourceGroup().id)
  scope: aks
  properties: {
    principalId: principalId
    roleDefinitionId: runcmdRole
  }
}
