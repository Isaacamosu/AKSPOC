param vnetName string
param vnetPrefix string
param aksSubnetPrefix string
param ilbSubnetPrefix string
param fwSubnetPrefix string
param mgmtSubnetPrefix string
param tags object


resource aksRouteTable 'Microsoft.Network/routeTables@2020-07-01' = {
  tags: tags
  name: 'aksRouteTable'
  location: resourceGroup().location
  properties: {
    routes: [
      {
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.50.4.4'
        }
        name: 'defaultRoute'
      }
    ]
    disableBgpRoutePropagation: true

  }
}


resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  tags: tags
  location: resourceGroup().location
  properties:{
    addressSpace:{
      addressPrefixes:[
        vnetPrefix
      ]
    }
    subnets:[
      {
        name: 'aks'
        properties:{
          addressPrefix: aksSubnetPrefix
          routeTable:{
            id: aksRouteTable.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'ilb'
        properties:{
          addressPrefix: ilbSubnetPrefix
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties:{
          addressPrefix: fwSubnetPrefix
        }
      }
      {
        name: 'mgmt'
        properties:{
          addressPrefix: mgmtSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
        
      }
    ]
    
  }
}

    

output mgmtSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'mgmt')
output aksSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks')
output fwSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet')
output Id string = vnet.id
