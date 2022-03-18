configuration CreateADPDC 

{
#Variable for an array object of Availability Group replicas
$replicas = @()

#Variable for T-SQL command
$createLogin = "CREATE LOGIN [testcorp.local\sqlservice] FROM WINDOWS; " 
$grantConnectPermissions = “GRANT CONNECT ON ENDPOINT::Endpoint_AG TO [testcorp.local\sqlservice];” 


#List all of the WSFC nodes all WSFC nodes; all SQL Server instances run DEFAULT instances
foreach($node in Get-ClusterNode)
{
   #Step 1: Enable SQL Server Always On High Availability feature
   Enable-SqlAlwaysOn -ServerInstance $node -Force 

   #Step 2: Create the Availability Group endpoints
   New-SqlHADREndpoint -Path "SQLSERVER:\SQL\$node\Default" -Name "Endpoint_AG" -Port 5022 -EncryptionAlgorithm Aes -Encryption Required 

   #Step 3: Start the Availability Group endpoint
   Set-SqlHADREndpoint -Path "SQLSERVER:\SQL\$node\Default\Endpoints\Endpoint_AG" -State Started
   
   #Step 4: Create login and grant CONNECT permissions to the SQL Server service account
   Invoke-SqlCmd -Server $node.Name -Query $createLogin
   Invoke-SqlCmd -Server $node.Name -Query $grantConnectPermissions 

   #Step 5: Create the Availability Group replicas as template objects
    $replicas += New-SqlAvailabilityReplica -Name $node -EndpointUrl "TCP://$node.TESTDOMAIN.COM:5022" -AvailabilityMode "SynchronousCommit" -FailoverMode "Automatic" -AsTemplate -Version 13 
}

#Step 6: Create the Availability Group, replace SERVERNAME with the name of the primary replica instance
New-SqlAvailabilityGroup -InputObject "WSFC2016-NODE1" -Name "AG_Prod" -AvailabilityReplica $replicas -Database @("Northwind")

#Step 7: Join the secondary replicas and databases to the Availability Group
Join-SqlAvailabilityGroup -Path “SQLSERVER:\SQL\WSFC2016-NODE2\Default” -Name “AG_Prod”
Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\WSFC2016-NODE2\Default\AvailabilityGroups\AG_Prod" -Database "Northwind" 
}