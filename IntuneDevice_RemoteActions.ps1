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

#########################################################################
# Intune Device Management Script
# 
# This script provides functionality to manage iOS devices in Microsoft Intune:
# 
# Features:
# - Perform Sync or Reboot actions on iOS devices
# - Target individual devices or Azure AD groups
# - Support for multiple device IDs or group IDs (comma-separated)
# - Delayed execution option for group-based actions
# - Continuous prompting for valid input (prevents script crashes)
# - Comprehensive error handling for invalid device/group IDs
# - Execution summary showing successful operations and invalid IDs
# 
# Required Permissions:
# - Access to Microsoft Graph
# - Appropriate Intune administration rights
#
# Usage:
# 1. Select action (Sync/Reboot)
# 2. Choose target type (Device IDs/Group IDs)
# 3. Provide IDs (comma-separated for multiple)
# 4. For group targets, specify delay time (0 for immediate)
#########################################################################

# Connect to Microsoft Graph API
Connect-MsGraph

# Function to handle user input validation
# Parameters:
# - prompt: The message to display to the user
# - validOptions: Array of acceptable input values
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

# Get and validate action selection from user
$action = Get-ValidInput -prompt "Please select the action to perform:
1. Sync Device
2. Reboot Device
Enter your choice (1 or 2)" -validOptions @('1', '2')

# Get and validate target selection from user
$choice = Get-ValidInput -prompt "Please provide the target resource for the action:
1. One or multiple Intune device ids (comma-separated)
2. One or multiple Azure group object ids (comma-separated)
Enter your choice (1 or 2)" -validOptions @('1', '2')

# Initialize arrays to track invalid IDs
$invalidDeviceIds = @()
$invalidGroupIds = @()

# Process user's target choice
switch ($choice) {
    "1" {
        # Handle individual device IDs
        $DeviceIds = Read-Host -Prompt "Please provide the Intune device id(s), separated by commas"
        # Convert comma-separated string to array of device objects
        $DeviceList = $DeviceIds.Split(',').Trim() | ForEach-Object {
            [PSCustomObject]@{deviceId = $_}
        }
        $delayMinutes = 0
    }
    "2" {
        # Handle group IDs
        $DeviceGroups = Read-Host -Prompt "Please provide the group object ID(s), separated by commas"
        
        # Get and validate delay time
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
        
        # Process each group and collect member devices
        $DeviceList = @()
        foreach ($GroupId in $DeviceGroups.Split(',').Trim()) {
            try {
                # Attempt to get devices from group
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

# Retrieve all iOS devices from Intune
$AllIntuneDevices = Get-IntuneManagedDevice -select id, operatingSystem, azureADDeviceId -Filter "contains(operatingSystem,'iOS')" | Get-MSGraphAllPages
Write-Host "`n"

# Handle delay if specified
if ($delayMinutes -gt 0) {
    Write-Host "Waiting for $delayMinutes minutes before execution..." -ForegroundColor Yellow
    Start-Sleep -Seconds ($delayMinutes * 60)
}

# Initialize counter for successful operations
$successfulCommands = 0

# Process each device in the list
foreach ($Device in $DeviceList) {
    # Match device with Intune device ID
    $deviceIntuneID = $AllIntuneDevices | Where-Object {$_.azureADDeviceId -eq $Device.deviceId}
    
    if ($deviceIntuneID.id) {
        # Device found, proceed with action
        Write-Host "Processing device: $($Device.deviceId)" -ForegroundColor Green
        if ($action -eq "1") {
            # Perform sync action
            Invoke-DeviceManagement_ManagedDevices_SyncDevice -managedDeviceId $deviceIntuneID.id
            Write-Host "Sync command has been sent to the device" -ForegroundColor Yellow
        }
        else {
            # Perform reboot action
            Invoke-DeviceManagement_ManagedDevices_RebootNow -managedDeviceId $deviceIntuneID.id
            Write-Host "Reboot command has been sent to the device" -ForegroundColor Yellow
        }
        $successfulCommands++
    }
    else {
        # Device not found in Intune
        $invalidDeviceIds += $Device.deviceId
        Write-Host "Invalid device ID: $($Device.deviceId)" -ForegroundColor Red
    }
}

# Display execution summary
Write-Host "`nExecution Summary:" -ForegroundColor Cyan

# Show number of successful commands
if ($action -eq "1") {
    Write-Host "Sync command has been sent to $successfulCommands devices" -ForegroundColor Green
}
else {
    Write-Host "Reboot command has been sent to $successfulCommands devices" -ForegroundColor Green
}

# Show invalid IDs if any
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
