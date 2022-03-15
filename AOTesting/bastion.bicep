param location string
param resourceGroup string
param bastionHostName string
param subnetName string
param publicIpAddressName string
param existingVNETName string
param subnetAddressPrefix string

resource publicIpAddressName_resource 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: {}
}

resource existingVNETName_subnetName 'Microsoft.Network/virtualNetworks/subnets@2018-04-01' = {
  name: '${existingVNETName}/${subnetName}'
  location: location
  properties: {
    addressPrefix: subnetAddressPrefix
  }
}

resource bastionHostName_resource 'Microsoft.Network/bastionHosts@2018-10-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId(resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', existingVNETName, subnetName)
          }
          publicIPAddress: {
            id: resourceId(resourceGroup, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
          }
        }
      }
    ]
  }
  tags: {}
  dependsOn: [
    resourceId(resourceGroup, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
  ]
}