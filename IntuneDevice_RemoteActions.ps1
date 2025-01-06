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

# Function: Prompt user for a valid input from a set of choices
function Prompt-ValidInput {
    param (
        [string]$PromptMessage,
        [string[]]$ValidChoices
    )
    do {
        $input = Read-Host -Prompt $PromptMessage
        if ($input -notin $ValidChoices) {
            Write-Host "Invalid input. Please select one of the following: $($ValidChoices -join ', ')." -ForegroundColor Yellow
        }
    } until ($input -in $ValidChoices)
    return $input
}

# Function: Prompt for a non-negative integer (e.g., delay time)
function Prompt-PositiveInteger {
    param ([string]$PromptMessage)
    do {
        $input = Read-Host -Prompt $PromptMessage
        if ($input -match '^\d+$') {
            return [int]$input
        } else {
            Write-Host "Invalid input. Please enter a non-negative integer." -ForegroundColor Yellow
        }
    } until ($false) # Loop continues until valid input
}

# Function: Validate device or group IDs
function Validate-Ids {
    param (
        [string[]]$Ids,
        [string]$Type,
        [object[]]$AllDevices
    )
    $ValidIds = @()
    $InvalidIds = @()

    foreach ($Id in $Ids) {
        if ($Type -eq "device") {
            # Check if the device ID exists in Intune
            $Device = $AllDevices | Where-Object { $_.azureADDeviceId -eq $Id }
            if ($Device) { $ValidIds += [PSCustomObject]@{ deviceId = $Id } }
            else { $InvalidIds += $Id }
        }
        elseif ($Type -eq "group") {
            # Check if the group ID exists in Azure AD
            try {
                $GroupExists = Get-AzureADGroup -ObjectId $Id
                if ($GroupExists) {
                    $GroupDevices = Get-Groups_Members -groupId $Id -Select id, deviceId, displayName | Get-MSGraphAllPages
                    $ValidIds += $GroupDevices
                } else { $InvalidIds += $Id }
            } catch {
                $InvalidIds += $Id
            }
        }
    }
    return @{
        ValidIds = $ValidIds
        InvalidIds = $InvalidIds
    }
}

# Prompt user for action type
$actionChoice = Prompt-ValidInput -PromptMessage @"
Which action would you like to perform?
1. Sync Device
2. Reboot Device
Enter your choice (1 or 2):
"@ -ValidChoices @("1", "2")

# Retrieve all Intune devices
$AllIntuneDevices = Get-IntuneManagedDevice -select id, operatingSystem, azureADDeviceId | Get-MSGraphAllPages

# Prompt user for target (devices or groups)
$targetChoice = Prompt-ValidInput -PromptMessage @"
Please provide the target resource for the action:
1. One or multiple Intune device IDs (comma-separated)
2. One or multiple Azure group object IDs (comma-separated)
Enter your choice (1 or 2):
"@ -ValidChoices @("1", "2")

$ValidDeviceList = @()
$InvalidIds = @()
$delayMinutes = 0

# Process the selected target type
switch ($targetChoice) {
    "1" {
        $DeviceIds = Read-Host -Prompt "Provide the Intune device ID(s), separated by commas"
        $ValidationResult = Validate-Ids -Ids ($DeviceIds.Split(',').Trim()) -Type "device" -AllDevices $AllIntuneDevices
        $ValidDeviceList = $ValidationResult.ValidIds
        $InvalidIds = $ValidationResult.InvalidIds
    }
    "2" {
        $GroupIds = Read-Host -Prompt "Provide the Azure group object ID(s), separated by commas"
        $ValidationResult = Validate-Ids -Ids ($GroupIds.Split(',').Trim()) -Type "group" -AllDevices $AllIntuneDevices
        $ValidDeviceList = $ValidationResult.ValidIds
        $InvalidIds = $ValidationResult.InvalidIds

        # Prompt user for delay time
        $delayMinutes = Prompt-PositiveInteger -PromptMessage "Enter delay time in minutes (0 for immediate execution)"
    }
}

# Apply delay if specified
if ($delayMinutes -gt 0) {
    Write-Host "`nWaiting for $delayMinutes minutes before execution..." -ForegroundColor Yellow
    Start-Sleep -Seconds ($delayMinutes * 60)
}

# Display invalid IDs
if ($InvalidIds.Count -gt 0) {
    Write-Host "`nThe following IDs are invalid and will be skipped:" -ForegroundColor Red
    foreach ($InvalidId in $InvalidIds) {
        Write-Host "❌ $InvalidId" -ForegroundColor Yellow
    }
}

# Perform the selected action on valid devices
Write-Host "`n--- Starting Action Execution ---`n" -ForegroundColor Cyan

foreach ($Device in $ValidDeviceList) {
    $DeviceIntune = $AllIntuneDevices | Where-Object { $_.azureADDeviceId -eq $Device.deviceId }
    if ($DeviceIntune.id) {
        switch ($actionChoice) {
            "1" {
                Invoke-DeviceManagement_ManagedDevices_SyncDevice -managedDeviceId $DeviceIntune.id
                Write-Host "✅ Sync command sent to device ID: $($Device.deviceId)" -ForegroundColor Green
            }
            "2" {
                Invoke-DeviceManagement_ManagedDevices_RebootNow -managedDeviceId $DeviceIntune.id
                Write-Host "✅ Reboot command sent to device ID: $($Device.deviceId)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "❌ Device ID '$($Device.deviceId)' not found in Intune." -ForegroundColor Red
    }
}

Write-Host "`n--- Action Execution Completed ---`n" -ForegroundColor Cyan
