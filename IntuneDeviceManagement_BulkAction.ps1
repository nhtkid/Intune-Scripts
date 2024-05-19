# Import the required module
Import-Module Microsoft.Graph.DeviceManagement

# Step 1: Connect to Microsoft Graph with required scopes
$Scopes = @(
    "DeviceManagementManagedDevices.ReadWrite.All",
    "GroupMember.Read.All"
)
Connect-MgGraph -Scopes $Scopes

# Step 2: Prompt the user to provide an AAD group object ID
$DeviceGroup = Read-Host -Prompt "Please provide the AAD group object ID"

# Step 3: Print out all the objects in that group
$DeviceList = Get-MgGroupMember -GroupId $DeviceGroup -ConsistencyLevel eventual | Get-MgGraphAllPages
$DeviceList | Format-Table

# Step 4: Convert the AAD object ID to Intune device ID
$AllIntuneDevices = Get-MgDeviceManagementManagedDevice -Filter "contains(operatingSystem, 'iOS')" | Get-MgGraphAllPages

foreach ($Device in $DeviceList) {
    $deviceIntune = $AllIntuneDevices | Where-Object { $_.AzureADDeviceId -eq $Device.Id }

    Write-Host $Device.Id

    if ($deviceIntune) {
        # Step 5: Use Invoke command to call different remote actions to these devices
        $result = Invoke-MgDeviceManagementManagedDeviceSyncDevice -ManagedDeviceId $deviceIntune.ManagedDeviceId

        Write-Host "Sync command has been sent to the device"
        Write-Host "Result: $result"
    } else {
        Write-Host "$Device.Id not found"
    }
}
