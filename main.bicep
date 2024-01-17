targetScope='subscription'

// resource group parameters
param rgName string = 'rg'
param location string = 'northeurope'
param deployRand string

// vnet parameters
param vnetName string = 'aks-vnet'
param vnetPrefix string = '10.50.0.0/16'
param aksSubnetPrefix string = '10.50.1.0/24'
param ilbSubnetPrefix string = '10.50.2.0/24'
param fwSubnetPrefix string = '10.50.4.0/24'
param mgmtSubnetPrefix string = '10.50.5.0/24'

// aks parameters
param aksClusterName string = 'aks-cluster'
param k8sVersion string = '1.27'
param SPN string 
param enableKeda bool = true
param enableVPA bool = true

// keyvault parameters
param keyVaultName string = '${aksClusterName}-kv-oow' // must be globally unique removing rand while testing to avoid too many KV's    '${aksClusterName}-kv-${deployRand}'

//param adminUsername string = 'azureuser'
param adminGroupObjectIDs array = [SPN]
@allowed([
  'Free'
  'Standard'
])
param aksSkuTier string = 'Standard'
param aksVmSize string = 'Standard_D2s_v3'
param aksNodes int = 1

@allowed([
  'azure'
  'calico'
])
param aksNetworkPolicy string = 'calico'

// fw parameters
param fwName string = 'aks-fw'
var applicationRuleCollections = [
  {
    name: 'aksFirewallRules'
    properties: {
      priority: 100
      action: {
        type: 'allow'
      }
      rules: [
        {
          name: 'aksFirewallRules'
          description: 'Rules needed for AKS to operate'
          sourceAddresses: [
            aksSubnetPrefix
          ]
          protocols: [
            {
              protocolType: 'Https'
              port: 443
            }
            {
              protocolType: 'Http'
              port: 80
            }
          ]
          targetFqdns: [
            //'*.hcp.${rg.location}.azmk8s.io'
            '*.hcp.westeurope.azmk8s.io'
            'mcr.microsoft.com'
            '*.cdn.mcr.io'
            '*.data.mcr.microsoft.com'
            'management.azure.com'
            'login.microsoftonline.com'
            'dc.services.visualstudio.com'
            '*.ods.opinsights.azure.com'
            '*.oms.opinsights.azure.com'
            '*.monitoring.azure.com'
            'packages.microsoft.com'
            'acs-mirror.azureedge.net'
            'azure.archive.ubuntu.com'
            'security.ubuntu.com'
            'changelogs.ubuntu.com'
            'launchpad.net'
            'ppa.launchpad.net'
            'keyserver.ubuntu.com'
          ]
        }
      ]
    }
  }
]
var networkRuleCollections = [
  {
    name: 'ntpRule'
    properties: {
      priority: 100
      action: {
        type: 'allow'
      }
      rules: [
        {
          name: 'ntpRule'
          description: 'Allow Ubuntu NTP for AKS'
          protocols: [
            'UDP'
          ]
          sourceAddresses: [
            aksSubnetPrefix
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '123'
          ]
        }
      ]
    }
  }
]

// acr parameters
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'
param acrName string = 'aksacrdiageo'
param acrAdminUserEnabled bool = true


// role parameters
param acrRole string
param runcmdRole string
param aksrbacRole string
param kvsecRole string

// Tag object

param mandatoryTags object = {
  acctBAUCostCentre: 'AEL401'
  funcAppID: '0000'
  funcAppOwner: 'funcAppOwner'
  funcAppName: 'Diageo AKS IaC project'
}

resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' existing = {
  name: rgName
}

module vnet 'modules/aks_vnet.bicep' = {
  name: vnetName
  scope: rg
  params: {
    tags: mandatoryTags
    vnetName: vnetName
    vnetPrefix: vnetPrefix
    aksSubnetPrefix: aksSubnetPrefix
    ilbSubnetPrefix: ilbSubnetPrefix
    fwSubnetPrefix: fwSubnetPrefix
    mgmtSubnetPrefix: mgmtSubnetPrefix
  }
}

module fw 'modules/azfw.bicep' = {
  dependsOn: [
    vnet
  ]
  name: fwName
  scope: rg
  params: {
    tags: mandatoryTags
    fwName: fwName
    fwSubnetId: vnet.outputs.fwSubnetId
    applicationRuleCollections: applicationRuleCollections
    networkRuleCollections: networkRuleCollections
  }
}


module aks 'modules/aks_cluster.bicep' = {
  name: aksClusterName
  dependsOn: [
    fw
  ]
  scope: rg
  params: {    
    tags: mandatoryTags
    aksClusterName: aksClusterName
    subnetId: vnet.outputs.aksSubnetId
    SPN: SPN
    aksSettings: {
      clusterName: aksClusterName
      identity: 'SystemAssigned'
      kubernetesVersion: k8sVersion
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: aksNetworkPolicy
      serviceCidr: '172.16.0.0/22' // can be reused in multiple clusters; no overlap with other IP ranges
      dnsServiceIP: '172.16.0.10'
      outboundType: 'loadBalancer'
      loadBalancerSku: 'standard'
      sku_tier: aksSkuTier			
      enableRBAC: true 
      aadProfileManaged: true
      adminGroupObjectIDs: adminGroupObjectIDs
      enableKeda: true
      enableVPA: true
      disableLocalAccounts: true
    }

    defaultNodePool: {
      name: 'pool01' // Add Autoscaling to nodepool also Add a user nodepool
      count: aksNodes
      vmSize: aksVmSize
      osDiskSizeGB: 50
      osDiskType: 'Ephemeral'
      vnetSubnetID: vnet.outputs.aksSubnetId
      osType: 'Linux'
      type: 'VirtualMachineScaleSets'
      mode: 'System'
    }    
  }
}

module acr 'modules/acr.bicep' = {
  dependsOn: [
    aks
  ]
  name: acrName
  scope: rg
  params:{
    tags: mandatoryTags
    acrName: acrName
    acrSku: acrSku
    acrAdminUserEnabled: acrAdminUserEnabled
    acrSubnet: vnet.outputs.mgmtSubnetId
    vnetId: vnet.outputs.Id
  }
}

module kv 'modules/aks_keyvault.bicep' = {
  dependsOn: [
    acr
  ]
  name: keyVaultName
  scope: rg
  params: {
    vnetDnsLinkExist: acr.outputs.linkID 
    vnetId: vnet.outputs.Id
    acrSubnet: vnet.outputs.mgmtSubnetId
    location: location
    tenantId: subscription().tenantId
    tags: mandatoryTags
    keyVaultName: keyVaultName
  }
}

module aks_roleassign 'modules/aks_roleassignments.bicep' = {
  dependsOn: [
    acr
  ]
  name: 'aks_roleassign'
  scope: rg
  params: {
    spn: SPN
    acr_name: acrName
    aks_name: aksClusterName
    runcmdRole: runcmdRole
    acrRole: acrRole
    aksrbacRole: aksrbacRole
    principalId: aks.outputs.principalid
    kvsecrole: kvsecRole
    keyVaultName: keyVaultName
  }
}
