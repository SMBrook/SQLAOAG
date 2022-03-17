resource FailoverClusterName_Listener 'Microsoft.SqlVirtualMachine/sqlVirtualMachineGroups/availabilityGroupListeners@2021-11-01-preview' = {
  name: 'sqlcluster01/aglistener'
  properties: {
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
