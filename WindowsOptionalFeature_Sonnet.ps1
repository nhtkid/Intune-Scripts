<#
.SYNOPSIS
    This script manages Windows optional features by enabling or disabling specified features.

.DESCRIPTION
    The script performs the following actions:
    1. Enables specified Windows optional features if they are not already enabled.
    2. Disables specified Windows optional features if they are not already disabled.
    3. Logs all actions and their results to a file in C:\Windows\Logs\.
    4. Forces a system reboot if any changes were attempted, regardless of whether a reboot is required.

.NOTES
    - Run this script with administrative privileges.
    - The script will attempt to create a log file in C:\Windows\Logs\. Ensure the executing user has write permissions.
    - A forced reboot will occur if any changes are attempted, with a 10-second warning.
#>

# Define the features to be enabled and disabled
$featuresToEnable = @(
    "Client-DeviceLockdown-CustomLogon",
    "Client-DeviceLockdown-KeyboardFilter"
)

$featuresToDisable = @(
    "WindowsMediaPlayer",
    "Internet-Explorer-Optional-amd64"
)

# Set up logging
$logPath = "C:\Windows\Logs\WindowsFeatureManagement.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log {
    param(
        [string]$Message
    )
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Function to enable features
function Enable-WindowsFeatures($features) {
    foreach ($feature in $features) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -eq "Disabled") {
            Write-Log "Enabling feature: $feature"
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
            if ($result.RestartNeeded) {
                Write-Log "Feature $feature enabled successfully. Restart needed."
            } else {
                Write-Log "Feature $feature enabled successfully. No restart needed."
            }
            $script:changesApplied = $true
        } else {
            Write-Log "Feature $feature is already enabled. Skipping."
        }
    }
}

# Function to disable features
function Disable-WindowsFeatures($features) {
    foreach ($feature in $features) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -eq "Enabled") {
            Write-Log "Disabling feature: $feature"
            $result = Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
            if ($result.RestartNeeded) {
                Write-Log "Feature $feature disabled successfully. Restart needed."
            } else {
                Write-Log "Feature $feature disabled successfully. No restart needed."
            }
            $script:changesApplied = $true
        } else {
            Write-Log "Feature $feature is already disabled. Skipping."
        }
    }
}

# Variable to track if any changes were attempted
$script:changesApplied = $false

# Start logging
Write-Log "Script execution started"

# Enable specified features
Write-Log "Attempting to enable features"
Enable-WindowsFeatures $featuresToEnable

# Disable specified features
Write-Log "Attempting to disable features"
Disable-WindowsFeatures $featuresToDisable

# Reboot if any changes were attempted
if ($changesApplied) {
    Write-Log "Changes have been applied. Rebooting the system in 10 seconds..."
    Start-Sleep -Seconds 10
    Write-Log "Initiating system reboot"
    Restart-Computer -Force
} else {
    Write-Log "No changes were applied. No reboot necessary."
}

Write-Log "Script execution completed"
