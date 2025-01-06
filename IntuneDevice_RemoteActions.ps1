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
1. One or multiple Intune device ids (comma-separated)
2. One or multiple Azure group object ids (comma-separated)
Enter your choice (1 or 2)"

# Process user's choice
switch ($choice) {
    "1" {
        # Option 1: Single or multiple devices
        $DeviceIds = Read-Host -Prompt "Please provide the Intune device id(s), separated by commas"
        # Split the input string and create array of device objects
        $DeviceList = $DeviceIds.Split(',').Trim() | ForEach-Object {
            [PSCustomObject]@{deviceId = $_}
        }
        $delayMinutes = 0
    }
    "2" {
        # Option 2: Multiple device groups
        $DeviceGroups = Read-Host -Prompt "Please provide the group object ID(s), separated by commas"
        $delayMinutes = Read-Host -Prompt "Enter delay time in minutes (0 for immediate execution)"
        
        # Validate delay input
        if (-not [int]::TryParse($delayMinutes, [ref]$null)) {
            Write-Host "Invalid delay time. Please enter a number. Exiting script." -ForegroundColor Red
            exit
        }
        
        $DeviceList = @()
        # Process each group
        foreach ($GroupId in $DeviceGroups.Split(',').Trim()) {
            # Retrieve all devices in the current group
            $GroupDevices = Get-Groups_Members -groupId $GroupId -Select id, deviceId, displayName | Get-MSGraphAllPages
            $DeviceList += $GroupDevices
        }
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

# Apply delay if specified
if ($delayMinutes -gt 0) {
    Write-Host "Waiting for $delayMinutes minutes before execution..." -ForegroundColor Yellow
    Start-Sleep -Seconds ($delayMinutes * 60)
}

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
