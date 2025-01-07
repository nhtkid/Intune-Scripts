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

# Prompt user for action selection
$action = Read-Host -Prompt "Please select the action to perform:
1. Sync Device
2. Reboot Device
Enter your choice (1 or 2)"

# Validate action selection
if ($action -notin '1', '2') {
    Write-Host "Invalid action choice. Exiting script." -ForegroundColor Red
    exit
}

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
        # Execute selected action
        if ($action -eq "1") {
            Invoke-DeviceManagement_ManagedDevices_SyncDevice -managedDeviceId $deviceIntuneID.id
            Write-Host "Sync command has been sent to the device" -ForegroundColor Yellow
        }
        else {
            Invoke-DeviceManagement_ManagedDevices_RebootNow -managedDeviceId $deviceIntuneID.id
            Write-Host "Reboot command has been sent to the device" -ForegroundColor Yellow
        }
    }
    else {
        # Device not found
        Write-Host "$($Device.deviceId) not found" -ForegroundColor Red
    }
}





# Connect to Microsoft Graph
Connect-MsGraph

# Function to get valid input for options
function Get-ValidInput {
    param (
        [string]$prompt,
        [string[]]$validOptions
    )
    while ($true) {
        $input = Read-Host -Prompt $prompt
        if ($input -in $validOptions) {
            return $input
        }
        Write-Host "Invalid input. Please try again." -ForegroundColor Yellow
    }
}

# Get action selection with validation
$action = Get-ValidInput -prompt "Please select the action to perform:
1. Sync Device
2. Reboot Device
Enter your choice (1 or 2)" -validOptions @('1', '2')

# Get target selection with validation
$choice = Get-ValidInput -prompt "Please provide the target resource for the action:
1. One or multiple Intune device ids (comma-separated)
2. One or multiple Azure group object ids (comma-separated)
Enter your choice (1 or 2)" -validOptions @('1', '2')

# Initialize arrays for invalid IDs
$invalidDeviceIds = @()
$invalidGroupIds = @()

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
            try {
                # Retrieve all devices in the current group
                $GroupDevices = Get-Groups_Members -groupId $GroupId -Select id, deviceId, displayName | Get-MSGraphAllPages
                if ($GroupDevices) {
                    $DeviceList += $GroupDevices
                }
                else {
                    $invalidGroupIds += $GroupId
                    Write-Host "Invalid or empty group ID: $GroupId" -ForegroundColor Red
                }
            }
            catch {
                $invalidGroupIds += $GroupId
                Write-Host "Error processing group ID: $GroupId" -ForegroundColor Red
            }
        }
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

# Initialize counter for successful commands
$successfulCommands = 0

# Process each device in the list
foreach ($Device in $DeviceList) {
    # Find the corresponding Intune device
    $deviceIntuneID = $AllIntuneDevices | Where-Object {$_.azureADDeviceId -eq $Device.deviceId}
    
    if ($deviceIntuneID.id) {
        Write-Host "Processing device: $($Device.deviceId)" -ForegroundColor Green
        # Execute selected action
        if ($action -eq "1") {
            Invoke-DeviceManagement_ManagedDevices_SyncDevice -managedDeviceId $deviceIntuneID.id
            Write-Host "Sync command has been sent to the device" -ForegroundColor Yellow
        }
        else {
            Invoke-DeviceManagement_ManagedDevices_RebootNow -managedDeviceId $deviceIntuneID.id
            Write-Host "Reboot command has been sent to the device" -ForegroundColor Yellow
        }
        $successfulCommands++
    }
    else {
        # Track invalid device ID
        $invalidDeviceIds += $Device.deviceId
        Write-Host "Invalid device ID: $($Device.deviceId)" -ForegroundColor Red
    }
}

# Summary of execution
Write-Host "`nExecution Summary:" -ForegroundColor Cyan
# Display command summary
if ($action -eq "1") {
    Write-Host "Sync command has been sent to $successfulCommands devices" -ForegroundColor Green
}
else {
    Write-Host "Reboot command has been sent to $successfulCommands devices" -ForegroundColor Green
}

# Summary of invalid IDs
if ($invalidDeviceIds) {
    Write-Host "`nThe following device IDs were invalid:" -ForegroundColor Red
    $invalidDeviceIds | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
}
if ($invalidGroupIds) {
    Write-Host "`nThe following group IDs were invalid:" -ForegroundColor Red
    $invalidGroupIds | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
}
if (-not $invalidDeviceIds -and -not $invalidGroupIds) {
    Write-Host "All IDs were processed successfully." -ForegroundColor Green
}
