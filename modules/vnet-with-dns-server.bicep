param DNSServerAddress array
param virtualNetworkName string


resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2020-05-01' existing =  {
  name: virtualNetworkName
}

resource dns 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: virtualNetworkName
  properties: {
    dhcpOptions: {
      dnsServers: DNSServerAddress
    }
  }
  dependsOn: [
    existingVirtualNetwork
  ]
}
