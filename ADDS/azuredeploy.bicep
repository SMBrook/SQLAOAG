@description('The name of the administrator account of the new VM and domain')
param adminUsername string

@description('The password for the administrator account of the new VM and domain')
@secure()
param adminPassword string

@description('The FQDN of the Active Directory Domain to be created')
param domainName string

@description('The DNS prefix for the public IP address used by the Load Balancer')
param dnsPrefix string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D2s_v3'

@description('The location of resources, such as templates and DSC modules, that the template depends on')
param artifactsLocation string = 'https://raw.githubusercontent.com/SMBrook/SQLAOAG/main/ADDS/'

@description('Auto-generated token to access _artifactsLocation. Leave it blank unless you need to provide your own value.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Virtual machine name.')
param virtualMachineName string = 'adVM'

@description('Virtual network name.')
param virtualNetworkName string = 'adVNET'

@description('Virtual network address range.')
param virtualNetworkAddressRange string = '10.0.0.0/16'

@description('Load balancer front end IP address name.')
param loadBalancerFrontEndIPName string = 'LBFE'

@description('Backend address pool name.')
param backendAddressPoolName string = 'LBBE'

@description('Inbound NAT rules name.')
param inboundNatRulesName string = 'adRDP'

@description('Network interface name.')
param networkInterfaceName string = 'adNic'

@description('Private IP address.')
param privateIPAddress string = '10.0.0.4'

@description('Subnet name.')
param subnetName string = 'adSubnet'

@description('Subnet IP range.')
param subnetRange string = '10.0.0.0/24'

@description('Subnet IP range.')
param publicIPAddressName string = 'adPublicIP'

@description('Availability set name.')
param availabilitySetName string = 'adAvailabiltySet'

@description('Load balancer name.')
param loadBalancerName string = 'adLoadBalancer'

resource publicIPAddressName_resource 'Microsoft.Network/publicIPAddresses@2020-08-01' = {
  name: publicIPAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsPrefix
    }
  }
}

resource availabilitySetName_resource 'Microsoft.Compute/availabilitySets@2019-03-01' = {
  location: location
  name: availabilitySetName
  properties: {
    platformUpdateDomainCount: 20
    platformFaultDomainCount: 2
  }
  sku: {
    name: 'Aligned'
  }
}

module VNet 'modules/VNET.bicep' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), concat('nestedtemplates/vnet.json', parameters('_artifactsLocationSasToken')))]*/ = {
  name: 'VNet'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: subnetName
    subnetRange: subnetRange
    location: location
  }
}

resource loadBalancerName_resource 'Microsoft.Network/loadBalancers@2019-02-01' = {
  name: loadBalancerName
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: loadBalancerFrontEndIPName
        properties: {
          publicIPAddress: {
            id: publicIPAddressName_resource.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendAddressPoolName
      }
    ]
    inboundNatRules: [
      {
        name: inboundNatRulesName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, loadBalancerFrontEndIPName)
          }
          protocol: 'Tcp'
          frontendPort: 3389
          backendPort: 3389
          enableFloatingIP: false
        }
      }
    ]
  }
}

resource networkInterfaceName_resource 'Microsoft.Network/networkInterfaces@2019-02-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIPAddress
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendAddressPoolName)
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/inboundNatRules', loadBalancerName, inboundNatRulesName)
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    VNet
    loadBalancerName_resource
  ]
}

resource virtualMachineName_resource 'Microsoft.Compute/virtualMachines@2019-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    availabilitySet: {
      id: availabilitySetName_resource.id
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2016-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${virtualMachineName}_OSDisk'
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          name: '${virtualMachineName}_DataDisk'
          caching: 'ReadWrite'
          createOption: 'Empty'
          diskSizeGB: 20
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
          lun: 0
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName_resource.id
        }
      ]
    }
  }
  dependsOn: [
    loadBalancerName_resource
  ]
}

resource virtualMachineName_CreateADForest 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = {
  parent: virtualMachineName_resource
  name: 'CreateADForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: uri(artifactsLocation, 'DSC/CreateADPDC.zip${artifactsLocationSasToken}')
      ConfigurationFunction: 'CreateADPDC.ps1\\CreateADPDC'
      Properties: {
        DomainName: domainName
        AdminCreds: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

module UpdateVNetDNS 'modules/vnet-with-dns-server.bicep' /*TODO: replace with correct path to [uri(parameters('_artifactsLocation'), concat('nestedtemplates/vnet-with-dns-server.json', parameters('_artifactsLocationSasToken')))]*/ = {
  name: 'UpdateVNetDNS'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: subnetName
    subnetRange: subnetRange
    DNSServerAddress: [
      privateIPAddress
    ]
    location: location
  }
  dependsOn: [
    virtualMachineName_CreateADForest
  ]
}
