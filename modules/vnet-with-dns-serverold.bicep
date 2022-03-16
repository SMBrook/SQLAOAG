param DNSServerAddress array
param virtualNetworkName string
param location string = resourceGroup().location
param virtualNetworkAddressRange string

resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2020-05-01' existing =  {
  name: virtualNetworkName
}

resource dns 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: virtualNetworkName
  location:location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    dhcpOptions: {
      dnsServers: DNSServerAddress
    }
  }
  dependsOn: [
    existingVirtualNetwork
  ]
}
