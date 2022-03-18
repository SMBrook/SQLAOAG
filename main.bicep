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

@description('Domain Controller Virtual machine name.')
param advirtualMachineName string = 'adVM'

@description('Virtual network name.')
param virtualNetworkName string = 'SQLDevClusterVNET'

@description('Virtual network address range.')
param virtualNetworkAddressRange string = '10.100.0.0/16'

@description('DC IP address.')
param DCIPAddress string = '10.100.0.4'

@description('Subnet name.')
param adsubnetname string = 'ADSubnet'

@description('AD Subnet IP range.')
param adsubnetrange string = '10.100.0.0/24'

@description('Subnet name.')
param sqlsubnetname string = 'SQLSubnet'

@description('AD Subnet IP range.')
param sqlsubnetrange string = '10.100.1.0/24'

@description('Bastion name.')
param bastionHostName string = 'sqlaoagbastion'

@description('Bastion subnet.')
param bastionSubnetIpPrefix string = '10.100.2.0/24'

@maxLength(15)
@description('Specify the Windows Failover Cluster Name')
param failoverClusterName string = 'sqlcluster01'

@description('Specify an optional Organizational Unit (OU) on AD Domain where the CNO (Computer Object for Cluster Name) will be created (e.g. OU=testou,OU=testou2,DC=contoso,DC=com). Default is empty.')
param existingOuPath string = ''

@description('Specify the name of the storage account to be used for creating Cloud Witness for Windows server failover cluster')
param cloudWitnessName string = 'clwitness${uniqueString(resourceGroup().id)}'

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

@description('The admin user name of the SQL VMs')
param sqllocaladminUsername string = 'sqlvmadmin'

@description('The admin password of the SQL VMs')
@secure()
param sqllocaladminPassword string

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

param virtualMachineNamePrefix string ='sql'

var sqlVMNames = [for i in range(1, VirtualMachineCount): '${virtualMachineNamePrefix}-${i}']

param deploybastion bool = true

/*@description('Specify a name for the listener for SQL Availability Group')
param Listener string = 'aglistener'

@description('Specify the port for listener')
param ListenerPort int = 1433

@description('Specify the available private IP address for the listener from the subnet the existing Vms are part of.')
param ListenerIp string = '10.100.1.8'

@description('Specify the load balancer port number (e.g. 59999)')
param ProbePort int = 59999*/

//Create AVSet for DC - No longer needed?
/*
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
}*/

//Create VNET

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

//Create Bastion Host
module bastion 'modules/bastion.bicep'= if (deploybastion) {
  name: 'bastion'
  params: {
    bastionHostName: bastionHostName
    bastionSubnetIpPrefix: bastionSubnetIpPrefix
    vnetName: virtualNetworkName
    location: location
  }
  dependsOn: [
    VNet
  ]
}

//Create DC Nic

resource dcnic 'Microsoft.Network/networkInterfaces@2019-02-01' = {
  name: '${advirtualMachineName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: DCIPAddress
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

//Create Domain Controller VM

resource virtualMachineName_resource 'Microsoft.Compute/virtualMachines@2019-03-01' = {
  name: advirtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: advirtualMachineName
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
        name: '${advirtualMachineName}_OSDisk'
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          name: '${advirtualMachineName}_DataDisk'
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
          id: dcnic.id
        }
      ]
    }
  }
}

//Create AD Forest

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

//Update VNET DNS Setting to point to new DC
module UpdateVNetDNS 'modules/vnet-with-dns-server.bicep' = {
  name: 'UpdateVNetDNS'
  params: {
    adsubnetname:adsubnetname
    adsubnetrange:adsubnetrange
    sqlsubnetname:sqlsubnetname
    sqlsubnetrange:sqlsubnetrange
    location:location
    virtualNetworkAddressRange: virtualNetworkAddressRange
    virtualNetworkName: virtualNetworkName
    DNSServerAddress: [
      DCIPAddress
    ]
  }
  dependsOn: [
    virtualMachineName_CreateADForest
  ]
}

//Create SQL VM Nics

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
    UpdateVNetDNS
  ]
}]

//Create SQL VMs

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
      computerName: 'sqlVM-${vm}'
      adminUsername: sqllocaladminUsername
      adminPassword: sqllocaladminPassword
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

//Join SQL Servers to AD Domain

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
    UpdateVNetDNS
  ]
}]

//Create Failover Cluster Witness Storage Account

resource cloudWitnessName_resource 'Microsoft.Storage/storageAccounts@2018-07-01' = {
  name: cloudWitnessName
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  location: location
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
  dependsOn: [
    sqlvirtualMachineExtension
  ]
}

//Create Failover Cluster

resource failoverClusterName_resource 'Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups@2017-03-01-preview' = {
  name: failoverClusterName
  location: location
  properties: {
    sqlImageOffer: imageOffer
    sqlImageSku: 'Developer'
    wsfcDomainProfile: {
      domainFqdn: domainName
      ouPath: existingOuPath
      clusterBootstrapAccount: '${adminUsername}@${domainName}'
      clusterOperatorAccount: '${adminUsername}@${domainName}'
      sqlServiceAccount: '${adminUsername}@${domainName}'
      storageAccountUrl: reference(cloudWitnessName_resource.id, '2018-07-01').primaryEndpoints.blob
      storageAccountPrimaryKey: listKeys(cloudWitnessName_resource.id, '2018-07-01').keys[0].value
    }
  }
  dependsOn: [
    sqlvirtualMachineExtension
  ]
}

//Create SQL VM Resources in Azure and add to Failover Cluster

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
    sqlVirtualMachineGroupResourceId: failoverClusterName_resource.id
    wsfcDomainCredentials: {
      clusterBootstrapAccountPassword: adminPassword
      clusterOperatorAccountPassword: adminPassword
      sqlServiceAccountPassword: adminPassword
    }
}
}]


resource lb 'Microsoft.Network/loadBalancers@2020-05-01' = {
  name: 'sqllb1'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, sqlsubnetname)
          }
        }
      }
    ]
  }
  dependsOn: [
    sqlvirtualMachineExtension
  ]
}

//Failing from here, mainly I suspect because of line 549 which needs a list of the deployed vms in a comma delimited fashion, may need an array?
/*
var SqlVmResourceIdList = [for (vm, i) in sqlVMNames: resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines','sqlVM-${vm}')]

resource FailoverClusterName_Listener 'Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups/availabilityGroupListeners@2017-03-01-preview' = {
  name: '${failoverClusterName}/${Listener}'
  properties: {
    createDefaultAvailabilityGroupIfNotExist: true
    loadBalancerConfigurations: [
      {
        privateIpAddress: {
          ipAddress: ListenerIp
          subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, sqlsubnetname)
        }
        loadBalancerResourceId: lb.id
        probePort: ProbePort
        sqlVirtualMachineInstances: SqlVmResourceIdList
      } 
    ]
    port: ListenerPort
  }
  dependsOn: [
    Microsoft_SqlVirtualMachine_SqlVirtualMachines_virtualMachineName
  ]
}

*/





