# Set log file path
$logPath = "C:\Windows\Logs\EnableKeyboardFilterFeature.log"

# Function to write log messages
function Write-Log($Message) {
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Main script execution
Write-Log "Script execution started"

# 1. Check and enable DeviceLockdown and Client-KeyboardFilter features if necessary
$features = @("DeviceLockdown", "Client-KeyboardFilter")
foreach ($feature in $features) {
    $featureState = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
    if ($featureState -eq 'Disabled') {
        Write-Log "Enabling $feature feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
        Write-Log "$feature feature enabled successfully"
    } else {
        Write-Log "$feature feature is already enabled"
    }
}

# 2. Set and start the service
Write-Log "Configuring MsKeyboardFilter service..."
Set-Service -Name "MsKeyboardFilter" -StartupType Automatic
Start-Service -Name "MsKeyboardFilter"
Write-Log "MsKeyboardFilter service configured and started"

# Script execution completed
Write-Log "Script execution completed"
