param location string
param sqlServerLicenseType string
param groupResourceId string
param virtualMachineResourceId string
param name string


@secure()
param domainAccountPassword string

@secure()
param sqlServicePassword string

resource existingVirtualMachineNames_resource 'Microsoft.SqlVirtualMachine/SqlVirtualMachines@2017-03-01-preview' = {
  name: name
  location: location
  properties: {
    virtualMachineResourceId: virtualMachineResourceId
    sqlServerLicenseType: sqlServerLicenseType
    sqlVirtualMachineGroupResourceId: groupResourceId
    wsfcDomainCredentials: {
      clusterBootstrapAccountPassword: domainAccountPassword
      clusterOperatorAccountPassword: domainAccountPassword
      sqlServiceAccountPassword: sqlServicePassword
    }
  }
}
