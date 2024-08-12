<#
.SYNOPSIS
    Manages Windows optional features and configures the KeyboardFilter service.
    Use @() for $featuresToEnable or $featuresToDisable if no changes are needed.
#>

$featuresToEnable = @("Client-KeyboardFilter", "Client-EmbeddedLogon")
$featuresToDisable = @("Internet-Explorer-Optional-amd64", "WindowsMediaPlayer")
$logPath = "C:\Windows\Logs\WindowsFeatureManagement.log"
$changesApplied = $false

function Write-Log($Message) {
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

function Manage-WindowsFeatures($features, $action) {
    foreach ($feature in $features) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
        if (($action -eq 'Enable' -and $state -eq 'Disabled') -or ($action -eq 'Disable' -and $state -eq 'Enabled')) {
            Write-Log "$action feature: $feature"
            $result = & "$action-WindowsOptionalFeature" -Online -FeatureName $feature -NoRestart
            Write-Log "Feature $feature ${action}d successfully. Restart needed: $($result.RestartNeeded)"
            $script:changesApplied = $true
            if ($feature -eq 'Client-KeyboardFilter' -and $action -eq 'Enable') {
                Configure-KeyboardFilterService
            }
        } else {
            Write-Log "Feature $feature is already $($action.ToLower())d. Skipping."
        }
    }
}

function Configure-KeyboardFilterService {
    try {
        Set-Service -Name "KeyboardFilter" -StartupType Automatic
        Start-Service -Name "KeyboardFilter"
        Write-Log "KeyboardFilter service configured and started"
    } catch {
        Write-Log "Error configuring KeyboardFilter service: $_"
    }
}

Write-Log "Script execution started"
Manage-WindowsFeatures $featuresToEnable 'Enable'
Manage-WindowsFeatures $featuresToDisable 'Disable'

if ($changesApplied) {
    Write-Log "Changes applied. Rebooting in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Log "No changes applied. No reboot necessary."
}

Write-Log "Script execution completed"
