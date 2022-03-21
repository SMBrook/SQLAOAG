param location string = 'uksouth'
param availabilityGroupName string = 'aoagagn2'
param resourceName string = 'sqlcluster01/aoaglistener2'
param ipAddress string = '10.100.1.11'
param subnetResourceId string = '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.Network/virtualNetworks/SQLDevClusterVNET/subnets/SQLSubnet'
param loadBalancerName string = 'aoaglb2'
param probePort int = 52725
param listenerPort int = 1433
param sku string = 'Standard'
param privateIPAllocationMethod string = 'Dynamic'

resource loadBalancerName_resource 'Microsoft.Network/loadBalancers@2019-06-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: sku
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          privateIPAllocationMethod: privateIPAllocationMethod
          subnet: {
            id: subnetResourceId
          }
        }
      }
    ]
  }
}

resource resourceName_resource 'Microsoft.SqlVirtualMachine/sqlVirtualMachineGroups/availabilityGroupListeners@2021-11-01-preview' = {
  name: resourceName
  location: location
  properties: {
    availabilityGroupName: availabilityGroupName
    loadBalancerConfigurations: [
      {
        privateIpAddress: {
          ipAddress: ipAddress
          subnetResourceId: subnetResourceId
        }
        loadBalancerResourceId: loadBalancerName_resource.id
        probePort: probePort
        sqlVirtualMachineInstances: [
          '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/sqlVM-sql-1'
          '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/sqlVM-sql-2'
          '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/sqlVM-sql-3'
        ]
      }
    ]
    port: listenerPort
    availabilityGroupConfiguration: {
      replicas: [
        {
          commit: 'Asynchronous_Commit'
          failover: 'Manual'
          readableSecondary: 'no'
          role: 'Primary'
          sqlVirtualMachineInstanceId: '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/sqlVM-sql-1'
        }
        {
          commit: 'Synchronous_Commit'
          failover: 'Automatic'
          readableSecondary: 'no'
          role: 'Secondary'
          sqlVirtualMachineInstanceId: '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/sqlVM-sql-2'
        }
        {
          commit: 'Synchronous_Commit'
          failover: 'Automatic'
          readableSecondary: 'no'
          role: 'Secondary'
          sqlVirtualMachineInstanceId: '/subscriptions/1ad7e9b0-b59b-42f7-a9f6-8d971cc1f1ea/resourceGroups/TESTSQL2/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/sqlVM-sql-3'
        }
      ]
    }
  }
}
