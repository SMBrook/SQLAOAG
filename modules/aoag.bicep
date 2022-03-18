param AGReplica array = [
  {
    commit: 'Synchronous_Commit'
    failover: 'Automatic'
    readableSecondary: 'no'
    role: 'Primary'
    sqlVMNo: 1
  }
  {
    commit: 'Asynchronous_Commit'
    failover: 'Manual'
    readableSecondary: 'no'
    role: 'Secondary'
    sqlVMNo: 2
  }
  {
    commit: 'Asynchronous_Commit'
    failover: 'Manual'
    readableSecondary: 'no'
    role: 'Secondary'
    sqlVMNo: 3
  }
]

resource createaoag 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = {
  name: 'CreateSQLAOAG'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: uri(artifactsLocation, 'DSC/aoag.zip${artifactsLocationSasToken}')
      ConfigurationFunction: 'aoag.zip\\aoag.zip'
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


resource FailoverClusterName_Listener 'Microsoft.SqlVirtualMachine/sqlVirtualMachineGroups/availabilityGroupListeners@2017-03-01-preview' = {
  name: 'sqlcluster01/aglistener'
  properties: {
    existingFailoverClustername: 
    createDefaultAvailabilityGroupIfNotExist: true
    loadBalancerConfigurations: [
      {
        privateIpAddress: {
          ipAddress: '10.100.1.8'
          subnetResourceId: '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/DCTester/providers/Microsoft.Network/virtualNetworks/adVNET/subnets/SQLSubnet'
        }
        loadBalancerResourceId: '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/DCTester/providers/Microsoft.Network/loadBalancers/sqllb1'
        probePort: 59999
        sqlVirtualMachineInstances: [
          '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/DCTester/providers/Microsoft.SqlVirtualMachine/SqlVirtualMachines/sqlVM-sql-1'
          '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/DCTester/providers/Microsoft.SqlVirtualMachine/SqlVirtualMachines/sqlVM-sql-2'
          '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/DCTester/providers/Microsoft.SqlVirtualMachine/SqlVirtualMachines/sqlVM-sql-3'
        ]
      } 
    ]
    
    port: 1433
  }
}
