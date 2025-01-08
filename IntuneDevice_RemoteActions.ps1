<#
    Intune Device Management Script
    
    This script provides functionality to manage Intune devices:
    
    Features:
    - Perform Sync or Reboot actions on iOS devices
    - Target individual devices or Azure AD groups
    - Support for multiple device IDs or group IDs (comma-separated)
    - Delayed execution option for group-based actions
    - Continuous prompting for valid input (prevents script crashes)
    - Comprehensive error handling for invalid device/group IDs
    - Execution summary showing successful operations and invalid IDs
    
    Requirement:
    - Install-Module AzureAD
    - Install-Module Microsoft.Graph.Intune
    - Appropriate Intune administration rights
    
    Possible actions for Invoke-DeviceManagement_ManagedDevices:
    - Invoke-DeviceManagement_ManagedDevices_RebootNow: Reboots the device
    - Invoke-DeviceManagement_ManagedDevices_SyncDevice: Syncs device information
    - Invoke-DeviceManagement_ManagedDevices_RemoteLock: Locks the device remotely
    - Invoke-DeviceManagement_ManagedDevices_RequestRemoteAssistance: Requests remote assistance
    - Invoke-DeviceManagement_ManagedDevices_ResetPasscode: Resets the device passcode
    - Invoke-DeviceManagement_ManagedDevices_Retire: Retires the device
    - Invoke-DeviceManagement_ManagedDevices_WindowsDefenderScan: Initiates a Windows Defender scan (for Windows devices)

    IMPORTANT:
    Please use Entra Device ID(s) or AAD Group Object ID. 
    Manually change "contains(operatingSystem,'iOS')" to 'Windows' to target other systems
#>

# Initialize connection to Microsoft Graph API - required for all Intune operations
Connect-MsGraph

# Helper function to ensure user input is valid and matches expected values
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

# User interface section - Get action type (Sync/Reboot)
$action = Get-ValidInput -prompt "Please select the action to perform:
1. Sync Device
2. Reboot Device
Enter your choice (1 or 2)" -validOptions @('1', '2')

# Get target type (Device IDs vs Group IDs)
$choice = Get-ValidInput -prompt "Please provide the target resource for the action:
1. One or multiple Intune device ids (comma-separated)
2. One or multiple Azure group object ids (comma-separated)
Enter your choice (1 or 2)" -validOptions @('1', '2')

# Arrays to track any IDs that couldn't be processed
$invalidDeviceIds = @()
$invalidGroupIds = @()

# Process targets based on user choice
switch ($choice) {
    "1" {
        # Direct device ID processing
        $DeviceIds = Read-Host -Prompt "Please provide the Intune device id(s), separated by commas"
        # Convert input string to array of device objects
        $DeviceList = $DeviceIds.Split(',').Trim() | ForEach-Object {
            [PSCustomObject]@{deviceId = $_}
        }
        $delayMinutes = 0
    }
    "2" {
        # Group-based processing
        $DeviceGroups = Read-Host -Prompt "Please provide the group object ID(s), separated by commas"
        
        # Get delay time for group processing
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

# Get all iOS devices from Intune for validation
$AllIntuneDevices = Get-IntuneManagedDevice -select id, operatingSystem, azureADDeviceId -Filter "contains(operatingSystem,'iOS')" | Get-MSGraphAllPages
Write-Host "`n"

# Handle specified delay if any
if ($delayMinutes -gt 0) {
    Write-Host "Waiting for $delayMinutes minutes before execution..." -ForegroundColor Yellow
    Start-Sleep -Seconds ($delayMinutes * 60)
}

# Track successful operations
$successfulCommands = 0

# Main processing loop - handle each device
foreach ($Device in $DeviceList) {
    # Match the device with its Intune ID
    $deviceIntuneID = $AllIntuneDevices | Where-Object {$_.azureADDeviceId -eq $Device.deviceId}
    
    if ($deviceIntuneID.id) {
        # Process valid device
        Write-Host "Processing device: $($Device.deviceId)" -ForegroundColor Green
        if ($action -eq "1") {
            # Execute sync command
            Invoke-DeviceManagement_ManagedDevices_SyncDevice -managedDeviceId $deviceIntuneID.id
            Write-Host "Sync command has been sent to the device" -ForegroundColor Yellow
        }
        else {
            # Execute reboot command
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

# Final execution summary
Write-Host "`nExecution Summary:" -ForegroundColor Cyan

# Report successful operations
if ($action -eq "1") {
    Write-Host "Sync command has been sent to $successfulCommands devices" -ForegroundColor Green
}
else {
    Write-Host "Reboot command has been sent to $successfulCommands devices" -ForegroundColor Green
}

# Report any invalid IDs
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
