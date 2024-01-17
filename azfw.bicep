param fwName string
param fwSubnetId string
param applicationRuleCollections array
param networkRuleCollections array
param tags object

resource fw_ip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  tags: tags
  name: '${fwName}-ip'
  location: resourceGroup().location
  sku:{
    name: 'Standard'
  }
  properties:{
    publicIPAllocationMethod:'Static'
    publicIPAddressVersion:'IPv4'
  }
}

resource fw 'Microsoft.Network/azureFirewalls@2023-04-01' = {
  tags: tags
  name: fwName
  location: resourceGroup().location
  properties:{
    sku:{
      tier:'Standard'
    }
    ipConfigurations:[
      {
        name: 'ipConfig1'
        properties:{
          publicIPAddress:{
            id: fw_ip.id
          }
          subnet:{
            id: fwSubnetId
          }
        }
      }
    ]
    applicationRuleCollections: applicationRuleCollections
    networkRuleCollections: networkRuleCollections
    
  }
}
