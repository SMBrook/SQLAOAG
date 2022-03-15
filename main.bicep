@description('The name of the administrator account of the new VM and domain')
param adminUsername string

@description('The password for the administrator account of the new VM and domain')
@secure()
param adminPassword string

@description('The FQDN of the Active Directory Domain to be created')
param domainName string = 'testcorp.local'

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D2s_v3'

@description('The location of resources, such as templates and DSC modules, that the template depends on')
param artifactsLocation string = 'https://raw.githubusercontent.com/SMBrook/SQLAOAG/main/'

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
param virtualNetworkAddressRange string = '10.100.0.0/16'

@description('Network interface name.')
param networkInterfaceName string = 'adNic'

@description('Private IP address.')
param privateIPAddress string = '10.100.0.4'

@description('Subnet name.')
param adsubnetname string = 'ADSubnet'

@description('AD Subnet IP range.')
param adsubnetrange string = '10.100.0.0/24'

@description('Subnet name.')
param sqlsubnetname string = 'SQLSubnet'

@description('AD Subnet IP range.')
param sqlsubnetrange string = '10.100.1.0/24'

@description('Availability set name.')
param availabilitySetName string = 'adAvailabiltySet'

@description('Bastion name.')
param bastionHostName string = 'sqlaoagbastion'

@description('Bastion subnet.')
param bastionSubnetIpPrefix string = '10.100.2.0/24'


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

module VNet 'modules/VNET.bicep'= {
  name: 'VNet'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    adsubnetname: adsubnetname
    adsubnetrange: adsubnetrange
    sqlsubnetname: sqlsubnetname
    sqlsubnetrange: sqlsubnetrange
    location: location
  }
}

module bastion 'modules/bastion.bicep'= {
  name: 'bastion'
  params: {
    bastionHostName: bastionHostName
    bastionSubnetIpPrefix: bastionSubnetIpPrefix
    vnetName: virtualNetworkName
    vnetIpPrefix: virtualNetworkAddressRange
    location: location
  }
  dependsOn: [
    VNet
    UpdateVNetDNS
  ]
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
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, adsubnetname)
          }
        }
      }
    ]
  }
  dependsOn: [
    VNet
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
        sku: '2019-Datacenter'
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
    adsubnetname: adsubnetname
    adsubnetrange: adsubnetrange
    sqlsubnetname: sqlsubnetname
    sqlsubnetrange: sqlsubnetrange
    DNSServerAddress: [
      privateIPAddress
    ]
    location: location
  }
  dependsOn: [
    virtualMachineName_CreateADForest
  ]
}

@description('The name of the VM')
param sqlvirtualMachineName string = 'sql1'

@description('The virtual machine size.')
param virtualMachineSize string = 'Standard_D8s_v3'

@allowed([
  'sql2019-ws2019'
  'sql2017-ws2019'
  'SQL2017-WS2016'
  'SQL2016SP1-WS2016'
  'SQL2016SP2-WS2016'
  'SQL2014SP3-WS2012R2'
  'SQL2014SP2-WS2012R2'
])
@description('Windows Server and SQL Offer')
param imageOffer string = 'sql2019-ws2019'

@allowed([
  'Standard'
  'Enterprise'
  'SQLDEV'
  'Web'
  'Express'
])
@description('SQL Server Sku')
param sqlSku string = 'SQLDEV'

@description('The admin user name of the VM')
param sqladminUsername string

@description('The admin password of the VM')
@secure()
param sqladminPassword string

@allowed([
  'GENERAL'
  'OLTP'
  'DW'
])
@description('SQL Server Workload Type')
param storageWorkloadType string = 'GENERAL'

@minValue(1)
@maxValue(8)
@description('Amount of data disks (100GB each) for SQL Data files')
param sqlDataDisksCount int = 2

@description('Path for SQL Data files. Please choose drive letter from F to Z, and other drives from A to E are reserved for system')
param dataPath string = 'F:\\SQLData'

@minValue(1)
@maxValue(8)
@description('Amount of data disks (100GB each) for SQL Log files')
param sqlLogDisksCount int = 2

@description('Path for SQL Log files. Please choose drive letter from F to Z and different than the one used for SQL data. Drive letter from A to E are reserved for system')
param logPath string = 'G:\\SQLLog'

var networkInterfaceName_var = '${sqlvirtualMachineName}-nic'
var diskConfigurationType = 'NEW'
var dataDisksLuns = array(range(0, sqlDataDisksCount))
var logDisksLuns = array(range(sqlDataDisksCount, sqlLogDisksCount))
var dataDisks = {
  createOption: 'Empty'
  caching: 'ReadOnly'
  writeAcceleratorEnabled: false
  storageAccountType: 'Premium_LRS'
  diskSizeGB: 100
}
var tempDbPath = 'D:\\SQLTemp'

@description('Specify number of VM instances to be created')
param VirtualMachineCount int = 3

param virtualMachineNamePrefix string

var sqlVMNames = [for i in range(1, VirtualMachineCount): '${virtualMachineNamePrefix}-${i}']

resource sqlnetworkInterfaceName 'Microsoft.Network/networkInterfaces@2020-06-01' = [for (vm, i) in sqlVMNames: {
  name: 'nic-${vm}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, sqlsubnetname)
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
  dependsOn: [
    VNet
  ]
}]


resource sqlvirtualMachineName_resource 'Microsoft.Compute/virtualMachines@2020-06-01' = [for (vm, i) in sqlVMNames: {
  name: 'sqlVM-${vm}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: imageOffer
        sku: sqlSku
        version: 'latest'
      }
      dataDisks: [for j in range(0, (sqlDataDisksCount + sqlLogDisksCount)): {
        lun: j
        createOption: dataDisks.createOption
        caching: ((j >= sqlDataDisksCount) ? 'None' : dataDisks.caching)
        writeAcceleratorEnabled: dataDisks.writeAcceleratorEnabled
        diskSizeGB: dataDisks.diskSizeGB
        managedDisk: {
          storageAccountType: dataDisks.storageAccountType
        }
      }]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', 'nic-${vm}')
        }
      ]
    }
    osProfile: {
      computerName: sqlvirtualMachineName
      adminUsername: sqladminUsername
      adminPassword: sqladminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
  }
  dependsOn: [
    UpdateVNetDNS
  ]
}]

resource sqlvirtualMachineExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for (vm, i) in sqlVMNames: {
  name: 'sqlVM-${vm}/joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainName
      ouPath: ''
      user: '${domainName}\\${adminUsername}'
      restart: true
      options: 3
    }
    protectedSettings: {
      Password: adminPassword
    }
  }
  dependsOn: [
    sqlvirtualMachineName_resource
  ]
}]


resource Microsoft_SqlVirtualMachine_SqlVirtualMachines_virtualMachineName 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2017-03-01-preview' = [for (vm, i) in sqlVMNames: {
  name: 'sqlVM-${vm}'
  location: location
  properties: {
    virtualMachineResourceId: resourceId('Microsoft.Compute/virtualMachines', 'sqlVM-${vm}')
    sqlManagement: 'Full'
    sqlServerLicenseType: 'PAYG'
    storageConfigurationSettings: {
      diskConfigurationType: diskConfigurationType
      storageWorkloadType: storageWorkloadType
      sqlDataSettings: {
        luns: dataDisksLuns
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLuns
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDbPath
      }
    }
  }
  dependsOn: [
    sqlvirtualMachineExtension
  ]
}]

output sqladminUsername string = sqladminUsername
