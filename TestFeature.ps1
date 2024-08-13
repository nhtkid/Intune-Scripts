<#
.SYNOPSIS
    Installs the Windows Keyboard Filter feature if needed, configures the service, and reboots if necessary.
#>

# Set log file path
$logPath = "C:\Windows\Logs\KeyboardFilterSetup.log"

# Function to write log messages
function Write-Log($Message) {
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Main script execution
Write-Log "Script execution started"

# 1. Check and install feature if necessary
$feature = "Client-KeyboardFilter"
$featureState = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State

if ($featureState -eq 'Disabled') {
    Write-Log "Installing $feature feature..."
    Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
    Write-Log "$feature feature installed successfully"
} else {
    Write-Log "$feature feature is already installed"
}

# 2. Set and start the service
Write-Log "Configuring MsKeyboardFilter service..."
Set-Service -Name "MsKeyboardFilter" -StartupType Automatic
Start-Service -Name "MsKeyboardFilter"
Write-Log "MsKeyboardFilter service configured and started"

# 3. Reboot
Write-Log "Rebooting system in 10 seconds..."
Start-Sleep -Seconds 10
Restart-Computer -Force
