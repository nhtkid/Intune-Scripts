<#
.SYNOPSIS
    Installs the Windows Keyboard Filter feature and configures the MsKeyboardFilter service.
#>

# Set log file path
$logPath = "C:\Windows\Logs\KeyboardFilterInstallation.log"

# Function to write log messages
function Write-Log($Message) {
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Function to install Keyboard Filter feature
function Install-KeyboardFilter {
    $feature = "Client-KeyboardFilter"
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
    
    if ($state -eq 'Disabled') {
        Write-Log "Installing feature: $feature"
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
        Write-Log "Feature $feature installed successfully. Restart needed: $($result.RestartNeeded)"
        return $result.RestartNeeded
    } else {
        Write-Log "Feature $feature is already installed. Skipping."
        return $false
    }
}

# Function to configure MsKeyboardFilter service
function Set-MsKeyboardFilterService {
    try {
        Write-Log "Configuring MsKeyboardFilter service..."
        Set-Service -Name "MsKeyboardFilter" -StartupType Automatic
        Write-Log "MsKeyboardFilter service set to Automatic startup"
        
        Start-Service -Name "MsKeyboardFilter"
        Write-Log "MsKeyboardFilter service started successfully"
        
        $service = Get-Service -Name "MsKeyboardFilter"
        Write-Log "Current MsKeyboardFilter service status: $($service.Status)"
    } catch {
        Write-Log "Error configuring MsKeyboardFilter service: $_"
    }
}

# Main script execution
Write-Log "Script execution started"

$restartNeeded = Install-KeyboardFilter

# Always configure and start the service, regardless of whether a restart is needed
Set-MsKeyboardFilterService

if ($restartNeeded) {
    Write-Log "Keyboard Filter installed and service configured. Rebooting in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Log "No reboot necessary. Script execution completed."
}
