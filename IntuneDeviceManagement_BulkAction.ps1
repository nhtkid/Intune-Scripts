# Install the Microsoft Graph PowerShell module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Connect to Microsoft Graph with the necessary permissions
Connect-MgGraph -Scopes @(
    "DeviceManagementManagedDevices.PrivilegedOperations.All",
    "GroupMember.Read.All",
    "Directory.Read.All"
)

# Prompt user to provide a group ID
$groupId = Read-Host "Enter the group ID"

# Get the list of managed devices in the specified group
$devices = Get-MgGroupMember -GroupId $groupId -All | Where-Object { $_.AdditionalProperties."@odata.type" -eq "#microsoft.graph.managedDevice" }

# Print out the devices and their attributes
Write-Host "Managed Devices in the group:"
foreach ($device in $devices) {
    $deviceId = $device.Id
    $deviceDetails = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId

    Write-Host "Device ID: $deviceId"
    Write-Host "Azure AD Device ID: $($deviceDetails.AzureAdDeviceId)"
    Write-Host "Device Name: $($deviceDetails.DeviceName)"
    Write-Host "Operating System: $($deviceDetails.OperatingSystem)"
    Write-Host "Manufacturer: $($deviceDetails.Manufacturer)"
    Write-Host "Model: $($deviceDetails.Model)"
    Write-Host "Last Sync Date Time: $($deviceDetails.LastSyncDateTime)"
    Write-Host "Enrollment Date Time: $($deviceDetails.EnrolledDateTime)"
    Write-Host "Compliance State: $($deviceDetails.ComplianceState)"
    Write-Host "Management Agent: $($deviceDetails.ManagementAgent)"
    Write-Host "---"
}

# Iterate through each device and send a remote reboot command
foreach ($device in $devices) {
    try {
        # Send the remote reboot command to the device
        Invoke-MgDeviceManagementManagedDeviceReboot -ManagedDeviceId $device.Id

        Write-Host "Remote reboot command sent successfully to device: $($device.Id)"
    }
    catch {
        Write-Host "Failed to send remote reboot command to device: $($device.Id). Error: $($_.Exception.Message)"
    }
}
