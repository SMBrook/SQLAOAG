@description('The name of the Virtual Network to Create')
param virtualNetworkName string

@description('The address range of the new VNET in CIDR format')
param virtualNetworkAddressRange string

@description('The name of the subnet created in the new VNET')
param adsubnetname string

@description('The address range of the subnet created in the new VNET')
param adsubnetrange string

@description('The name of the subnet created in the new VNET')
param sqlsubnetname string

@description('The name of the subnet created in the new VNET')
param sqlsubnetrange string

@description('Location for all resources.')
param location string

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    subnets: [
      {
        name: adsubnetname
        properties: {
          addressPrefix: adsubnetrange
        }
      }
      {
        name: sqlsubnetname
        properties: {
          addressPrefix: sqlsubnetrange
        }
      }
    ]
  }
}
