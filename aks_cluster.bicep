param aksClusterName string
param subnetId string
param SPN string
param tags object

param aksSettings object = {
  kubernetesVersion: null
  identity: 'SystemAssigned'
  networkPlugin: 'azure'
  networkPluginMode: 'overlay'
  networkPolicy: 'calico'
  serviceCidr: '172.16.0.0/22' // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
  dnsServiceIP: '172.16.0.10' // Ip Address for K8s DNS
  outboundType: 'UDR'
  loadBalancerSku: 'standard'
  sku_tier: 'Standard'				
  enableRBAC: true 
  aadProfileManaged: true
  adminGroupObjectIDs: [] 
  ManagedClusterCostAnalysis: true
  enableKeda: true
  enableVPA: true
}

param defaultNodePool object = {
  name: 'systempool01'
  count: 3
  vmSize: 'Standard_D2s_v3'
  osDiskSizeGB: 50
  osDiskType: 'Ephemeral'
  vnetSubnetID: subnetId
  osType: 'Linux'
  maxCount: 6
  minCount: 3
  enableAutoScaling: true
  type: 'VirtualMachineScaleSets'
  mode: 'System'
  orchestratorVersion: null
}

param applicationNodePool object = {
  name: 'userpool01'
  count: 3
  vmSize: 'Standard_D2s_v3'
  osDiskSizeGB: 50
  osDiskType: 'Ephemeral'
  vnetSubnetID: subnetId
  osType: 'Linux'
  maxCount: 6
  minCount: 3
  enableAutoScaling: true
  type: 'VirtualMachineScaleSets'
  mode: 'User'
  orchestratorVersion: null
}

resource aksAzureMonitor 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: '${aksClusterName}-logA'
  tags: tags
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerNode'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 30
    }
  }
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters?tabs=json#ManagedClusterAgentPoolProfile
resource aks 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' = {
  name: aksClusterName
  tags: tags
  location: resourceGroup().location
  identity: {
    type: aksSettings.identity
  }
  sku: {
    name: 'Base'
    tier: aksSettings.sku_tier
  }
  properties: {
    kubernetesVersion: aksSettings.kubernetesVersion
    dnsPrefix: aksSettings.clusterName
    
    addonProfiles: {
     
      azurepolicy: {
        enabled: true
        config: {
          version: 'v3'
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: aksAzureMonitor.id
        }
      }
    }

    enableRBAC: aksSettings.enableRBAC
    

    networkProfile: {
      networkPlugin: aksSettings.networkPlugin 
      networkPolicy: aksSettings.networkPolicy 
      networkPluginMode: aksSettings.networkPluginMode // Azure CNI Overlay mode 
      serviceCidr: aksSettings.serviceCidr  // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
      dnsServiceIP: aksSettings.dnsServiceIP // Ip Address for K8s DNS
      outboundType: aksSettings.outboundType 
      loadBalancerSku: aksSettings.loadBalancerSku 
    }

    aadProfile: {
      managed: aksSettings.aadProfileManaged
      enableAzureRBAC: aksSettings.enableRBAC
      adminGroupObjectIDs: aksSettings.adminGroupObjectIDs
    }

    autoUpgradeProfile: {}

    workloadAutoScalerProfile: {
      keda: {
        enabled: aksSettings.enableKeda
      }
      verticalPodAutoscaler: {
        enabled: aksSettings.enableVPA
      }
    }
    disableLocalAccounts: false
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'none'
      enablePrivateClusterPublicFQDN: true
      
    }

    agentPoolProfiles: [
      defaultNodePool
      applicationNodePool
    ]
  }
}


output principalid string = aks.properties.identityProfile.kubeletidentity.objectId
