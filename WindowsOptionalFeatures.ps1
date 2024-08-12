<#
.SYNOPSIS
    Manages Windows optional features and configures the MsKeyboardFilter service.
    Use @() for $featuresToEnable or $featuresToDisable if no changes are needed.
#>
# Define features to enable and disable
$featuresToEnable = @("Client-KeyboardFilter", "Client-EmbeddedLogon")
$featuresToDisable = @("Internet-Explorer-Optional-amd64", "WindowsMediaPlayer")
# Set log file path and initialize changes tracker
$logPath = "C:\Windows\Logs\WindowsFeatureManagement.log"
$changesApplied = $false
# Function to write log messages
function Write-Log($Message) {
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}
# Function to manage Windows features (enable or disable)
function Set-WindowsFeatures($features, $action) {
    foreach ($feature in $features) {
        # Check current state of the feature
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
        if (($action -eq 'Enable' -and $state -eq 'Disabled') -or ($action -eq 'Disable' -and $state -eq 'Enabled')) {
            Write-Log "$action feature: $feature"
            # Enable or disable the feature
            $result = & "$action-WindowsOptionalFeature" -Online -FeatureName $feature -NoRestart
            Write-Log "Feature $feature ${action}d successfully. Restart needed: $($result.RestartNeeded)"
            $script:changesApplied = $true
            # Configure MsKeyboardFilter service if enabling Client-KeyboardFilter
            if ($feature -eq 'Client-KeyboardFilter' -and $action -eq 'Enable') {
                Set-MsKeyboardFilterService
            }
        } else {
            Write-Log "Feature $feature is already $($action.ToLower())d. Skipping."
        }
    }
}
# Function to configure MsKeyboardFilter service
function Set-MsKeyboardFilterService {
    try {
        # Set service to Automatic startup and start it
        Set-Service -Name "MsKeyboardFilter" -StartupType Automatic
        Start-Service -Name "MsKeyboardFilter"
        Write-Log "MsKeyboardFilter service configured and started"
    } catch {
        Write-Log "Error configuring MsKeyboardFilter service: $_"
    }
}
# Main script execution
Write-Log "Script execution started"
# Enable specified features
Set-WindowsFeatures $featuresToEnable 'Enable'
# Disable specified features
Set-WindowsFeatures $featuresToDisable 'Disable'
# Reboot if changes were applied
if ($changesApplied) {
    Write-Log "Changes applied. Rebooting in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Log "No changes applied. No reboot necessary."
}
Write-Log "Script execution completed"
