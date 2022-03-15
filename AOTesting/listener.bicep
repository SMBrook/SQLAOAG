@description('Specify the name of the failover cluster')
param existingFailoverClusterName string

@description('Specify the name of SQL Availability Group for which listener is being created')
param existingSqlAvailabilityGroup string

@description('Specify the Virtual machine list participating in SQL Availability Group e.g. VM1, VM2. Maximum number is 6.')
param existingVmList string

@description('Specify a name for the listener for SQL Availability Group')
param Listener string = 'aglistener'

@description('Specify the port for listener')
param ListenerPort int = 1433

@description('Specify the available private IP address for the listener from the subnet the existing Vms are part of.')
param ListenerIp string = '10.0.0.7'

@description('Specify the resourcegroup for virtual network')
param existingVnetResourcegroup string = resourceGroup().name

@description('Specify the virtual network for Listener IP Address')
param existingVnet string

@description('Specify the subnet under Vnet for Listener IP address')
param existingSubnet string

@description('Name of existing internal load balancer for the AG listener. Choose Standard Sku if the VMs are not in an availability set.')
param existingInternalLoadBalancer string

@description('Specify the load balancer port number (e.g. 59999)')
param ProbePort int = 59999

@description('Location for all resources.')
param Location string = resourceGroup().location

var LoadBalancerResourceId = resourceId('Microsoft.Network/loadBalancers', existingInternalLoadBalancer)
var SubnetResourceId = '${resourceId(existingVnetResourcegroup, 'Microsoft.Network/virtualNetworks', existingVnet)}/subnets/${existingSubnet}'
var VmArray = split(existingVmList, ',')
var VM0 = ((0 < length(VmArray)) ? createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(VmArray[0]))) : json('[]'))
var VM1 = ((1 < length(VmArray)) ? createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(VmArray[1]))) : json('[]'))
var VM2 = ((2 < length(VmArray)) ? createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(VmArray[2]))) : json('[]'))
var VM3 = ((3 < length(VmArray)) ? createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(VmArray[3]))) : json('[]'))
var VM4 = ((4 < length(VmArray)) ? createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(VmArray[4]))) : json('[]'))
var VM5 = ((5 < length(VmArray)) ? createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(VmArray[5]))) : json('[]'))
var SqlVmResourceIdList = union(VM0, VM1, VM2, VM3, VM4, VM5)

resource existingFailoverClusterName_Listener 'Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups/availabilityGroupListeners@2017-03-01-preview' = {
  name: '${existingFailoverClusterName}/${Listener}'
  location: Location
  properties: {
    availabilityGroupName: existingSqlAvailabilityGroup
    loadBalancerConfigurations: [
      {
        privateIpAddress: {
          ipAddress: ListenerIp
          subnetResourceId: SubnetResourceId
        }
        loadBalancerResourceId: LoadBalancerResourceId
        probePort: ProbePort
        sqlVirtualMachineInstances: SqlVmResourceIdList
      }
    ]
    port: ListenerPort
  }
}
