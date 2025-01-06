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
        
        # Loop until valid delay input is received
        $validInput = $false
        $delayMinutes = 0
        
        while (-not $validInput) {
            $delayInput = Read-Host -Prompt "Enter delay time in minutes (0 for immediate execution)"
            if ($delayInput -match '^\d+$') {
                $delayMinutes = [int]$delayInput
                $validInput = $true
            }
            else {
                Write-Host "Number Only" -ForegroundColor Yellow
            }
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










# Connect to Microsoft Graph
Connect-MsGraph

# Prompt user for action type
$actionChoice = Read-Host -Prompt @"
Which action would you like to perform?
1. Sync Device
2. Reboot Device
Enter your choice (1 or 2):
"@

# Validate action choice
if ($actionChoice -notin @("1", "2")) {
    Write-Host "Invalid action choice. Exiting script." -ForegroundColor Red
    exit
}

# Function to validate device or group IDs
function Validate-DeviceOrGroup {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Ids,
        [string]$Type
    )
    $ValidIds = @()
    foreach ($Id in $Ids) {
        if ($Type -eq "device") {
            # Check if the device ID exists in Intune
            $DeviceExists = $AllIntuneDevices | Where-Object { $_.azureADDeviceId -eq $Id }
            if ($DeviceExists) {
                $ValidIds += [PSCustomObject]@{ deviceId = $Id }
            } else {
                Write-Host "Device ID '$Id' not found in Intune." -ForegroundColor Yellow
            }
        }
        elseif ($Type -eq "group") {
            # Check if the group ID exists in Azure AD
            try {
                $GroupExists = Get-AzureADGroup -ObjectId $Id
                if ($GroupExists) {
                    $GroupDevices = Get-Groups_Members -groupId $Id -Select id, deviceId, displayName | Get-MSGraphAllPages
                    $ValidIds += $GroupDevices
                }
            } catch {
                Write-Host "Group ID '$Id' not found in Azure AD." -ForegroundColor Yellow
            }
        }
    }
    return $ValidIds
}

# Loop until valid input is provided for target choice
do {
    $targetChoice = Read-Host -Prompt @"
Please provide the target resource for the action:
1. One or multiple Intune device IDs (comma-separated)
2. One or multiple Azure group object IDs (comma-separated)
Enter your choice (1 or 2):
"@
} until ($targetChoice -in @("1", "2"))

$DeviceList = @()
$delayMinutes = 0

switch ($targetChoice) {
    "1" {
        do {
            $DeviceIds = Read-Host -Prompt "Please provide the Intune device ID(s), separated by commas"
            $DeviceList = Validate-DeviceOrGroup -Ids ($DeviceIds.Split(',').Trim()) -Type "device"
            if (-not $DeviceList) {
                Write-Host "No valid device IDs found. Please try again." -ForegroundColor Yellow
            }
        } until ($DeviceList.Count -gt 0)
    }
    "2" {
        do {
            $DeviceGroups = Read-Host -Prompt "Please provide the Azure group object ID(s), separated by commas"
            $DeviceList = Validate-DeviceOrGroup -Ids ($DeviceGroups.Split(',').Trim()) -Type "group"
            if (-not $DeviceList) {
                Write-Host "No valid group IDs or devices in the group were found. Please try again." -ForegroundColor Yellow
            }
        } until ($DeviceList.Count -gt 0)

        # Prompt for delay
        $validInput = $false
        while (-not $validInput) {
            $delayInput = Read-Host -Prompt "Enter delay time in minutes (0 for immediate execution)"
            if ($delayInput -match '^\d+$') {
                $delayMinutes = [int]$delayInput
                $validInput = $true
            }
            else {
                Write-Host "Invalid input. Please enter a valid number." -ForegroundColor Yellow
            }
        }
    }
}

# Retrieve all Intune devices
$AllIntuneDevices = Get-IntuneManagedDevice -select id, operatingSystem, azureADDeviceId | Get-MSGraphAllPages

# Apply delay if specified
if ($delayMinutes -gt 0) {
    Write-Host "`nWaiting for $delayMinutes minutes before execution..." -ForegroundColor Yellow
    Start-Sleep -Seconds ($delayMinutes * 60)
}

# Perform the selected action on each device in the list
Write-Host "`n--- Starting Action Execution ---`n" -ForegroundColor Cyan

foreach ($Device in $DeviceList) {
    $deviceIntuneID = $AllIntuneDevices | Where-Object {$_.azureADDeviceId -eq $Device.deviceId}
    if ($deviceIntuneID.id) {
        switch ($actionChoice) {
            "1" {
                # Sync Device
                Invoke-DeviceManagement_ManagedDevices_SyncDevice -managedDeviceId $deviceIntuneID.id
                Write-Host "✅ Sync command sent to device ID: $($Device.deviceId)" -ForegroundColor Green
            }
            "2" {
                # Reboot Device
                Invoke-DeviceManagement_ManagedDevices_RebootNow -managedDeviceId $deviceIntuneID.id
                Write-Host "✅ Reboot command sent to device ID: $($Device.deviceId)" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "❌ Device ID '$($Device.deviceId)' not found in Intune." -ForegroundColor Red
    }
}

Write-Host "`n--- Action Execution Completed ---`n" -ForegroundColor Cyan
