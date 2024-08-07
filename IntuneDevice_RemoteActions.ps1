# This script allows for management of Intune devices, either individually or in groups.
# It can perform various actions on iOS devices managed by Intune.

# Possible actions for Invoke-DeviceManagement_ManagedDevices:
# - Invoke-DeviceManagement_ManagedDevices_RebootNow: Reboots the device
# - Invoke-DeviceManagement_ManagedDevices_RemoteLock: Locks the device remotely
# - Invoke-DeviceManagement_ManagedDevices_RequestRemoteAssistance: Requests remote assistance
# - Invoke-DeviceManagement_ManagedDevices_ResetPasscode: Resets the device passcode
# - Invoke-DeviceManagement_ManagedDevices_Retire: Retires the device
# - Invoke-DeviceManagement_ManagedDevices_SyncDevice: Syncs device information
# - Invoke-DeviceManagement_ManagedDevices_WindowsDefenderScan: Initiates a Windows Defender scan (for Windows devices)

# Connect to Microsoft Graph
Connect-MsGraph

# Prompt user for action target
$choice = Read-Host -Prompt "Please provide the target resource for the action:
1. A single Intune device id
2. An Azure group object id

Enter your choice (1 or 2)"

# Process user's choice
switch ($choice) {
    "1" {
        # Option 1: Single device
        $DeviceId = Read-Host -Prompt "Please provide the Intune device id"
        # Create a single-element array for consistency with group processing
        $DeviceList = @([PSCustomObject]@{deviceId = $DeviceId})
    }
    "2" {
        # Option 2: Device group
        $Devicegroup = Read-Host -Prompt "Please provide the group object ID"
        # Retrieve all devices in the specified group
        $DeviceList = Get-Groups_Members -groupId $Devicegroup -Select id, deviceId, displayName | Get-MSGraphAllPages
    }
    default {
        # Invalid choice
        Write-Host "Invalid choice. Exiting script." -ForegroundColor Red
        exit
    }
}

# Retrieve all iOS devices managed by Intune
$AllIntuneDevices = Get-IntuneManagedDevice -select id, operatingSystem, azureADDeviceId -Filter "contains(operatingSystem,'iOS')" | Get-MSGraphAllPages

Write-Host "`n"

# Process each device in the list
foreach ($Device in $DeviceList) {
    # Find the corresponding Intune device
    $deviceIntuneID = $AllIntuneDevices | Where-Object {$_.azureADDeviceId -eq $Device.deviceId}

    Write-Host $Device.deviceId

    if ($deviceIntuneID.id) {
        # Device found, perform action (in this case, reboot)
        Invoke-DeviceManagement_ManagedDevices_RebootNow -managedDeviceId $deviceIntuneID.id
        Write-Host "Reboot command has been sent to the device" -ForegroundColor Yellow
    }
    else {
        # Device not found
        Write-Host "$($Device.deviceId) not found" -ForegroundColor Red
    }
}
