@description('The name of the VM')
param virtualMachineName string = 'myVM'

@description('The virtual machine size.')
param virtualMachineSize string = 'Standard_D8s_v3'

@description('Specify the name of the Subnet Name')
param sqlsubnet string = 'sqlsubnet'

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
param adminUsername string

@description('The admin password of the VM')
@secure()
param adminPassword string

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

@description('Location for all resources.')
param location string = resourceGroup().location

var networkInterfaceName_var = '${virtualMachineName}-nic'
var diskConfigurationType = 'NEW'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, sqlsubnetname)
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

resource networkInterfaceName 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: networkInterfaceName_var
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

resource virtualMachineName_resource 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: virtualMachineName
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
          id: networkInterfaceName.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
  }
}

resource Microsoft_SqlVirtualMachine_SqlVirtualMachines_virtualMachineName 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2017-03-01-preview' = {
  name: virtualMachineName
  location: location
  properties: {
    virtualMachineResourceId: virtualMachineName_resource.id
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
}

output adminUsername string = adminUsername
