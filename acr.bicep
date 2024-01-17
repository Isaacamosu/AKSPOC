param acrName string
param acrSku string
param acrAdminUserEnabled bool
param acrSubnet string
param vnetId string
param tags object
param location string = resourceGroup().location

resource acrpe 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  tags: tags
  name: 'acr-privend'
  location: location
  properties:{
    
    subnet:{
      id: acrSubnet
    }
    privateLinkServiceConnections:[
      {
        name: 'acr-privend'
        properties:{
          privateLinkServiceId: acr.id
          groupIds:[
            'registry'
          ]
        }
      }
    ]
  }
}

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  tags: tags
  name: 'privatelink.azurecr.io'
  location: 'global'

  resource privateDNSZoneNetworkLink 'virtualNetworkLinks@2020-06-01' = {
    tags: tags
    name: 'acrnetlink'
    location: 'global'
    properties:{
      registrationEnabled: false
      virtualNetwork:{
        id: vnetId
      }
    }
  }
  
}



resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: acrpe
  name: 'default'
  properties:{
    privateDnsZoneConfigs:[
      {
        name: 'privatelink-azurecr-io'
        properties:{
          privateDnsZoneId: privateDNSZone.id
        }
      }
    ]
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  tags: tags
  dependsOn: [
    privateDNSZone
  ]
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
    publicNetworkAccess: 'Disabled'
  }

}

output linkID string = privateDNSZone.id




