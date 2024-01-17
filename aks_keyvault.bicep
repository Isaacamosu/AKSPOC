param keyVaultName string
param tags object
param tenantId string
param acrSubnet string
param vnetId string
param vnetDnsLinkExist string
param location string = resourceGroup().location


resource kvpe 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  tags: tags
  name: 'kv-privend'
  location: location
  properties:{
    
    subnet:{
      id: acrSubnet
    }
    privateLinkServiceConnections:[
      {
        name: 'kv-privend'
        properties:{
          privateLinkServiceId: keyVault.id
          groupIds:[
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (vnetDnsLinkExist == 'null')  {
  tags: tags
  name: 'privatelink.azurecr.io'
  location: 'global'

  resource privateDNSZoneNetworkLink 'virtualNetworkLinks@2020-06-01' = {
    tags: tags
    name: 'kvnetlink'
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
  parent: kvpe
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

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: 'disabled'
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
  }
}



