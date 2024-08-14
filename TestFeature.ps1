<#
.SYNOPSIS
    Installs the Windows Keyboard Filter feature if needed, configures the service, and reboots the system.
.DESCRIPTION
    This script is designed for deployment via Intune. It checks for the Windows Keyboard Filter feature, 
    installs it if not present, attempts to configure and start the service, and then initiates a system reboot.
    A scheduled task is created to ensure the service starts after reboot.
#>

# Set log file path
$logPath = "C:\Windows\Logs\EnableKeyboardFilterFeature.log"

# Function to write log messages
function Write-Log {
    param (
        [string]$Message
    )
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Function to create a scheduled task for post-reboot service configuration
function Set-PostRebootTask {
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
        -Argument '-NoProfile -WindowStyle Hidden -Command "Set-Service -Name MsKeyboardFilter -StartupType Automatic; Start-Service -Name MsKeyboardFilter; Unregister-ScheduledTask -TaskName KeyboardFilterSetup -Confirm:$false"'
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "KeyboardFilterSetup" -Action $action -Trigger $trigger -Principal $principal -Description "Configure Keyboard Filter Service after reboot"
}

# Main script execution
try {
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

    # 2. Attempt to configure and start the service
    Write-Log "Attempting to configure and start MsKeyboardFilter service..."
    try {
        Set-Service -Name "MsKeyboardFilter" -StartupType Automatic
        Start-Service -Name "MsKeyboardFilter"
        Write-Log "MsKeyboardFilter service configured and started successfully"
    }
    catch {
        Write-Log "Unable to start MsKeyboardFilter service. It will be started after reboot: $_"
    }

    # 3. Set up post-reboot task to ensure service is started
    Write-Log "Setting up post-reboot task to ensure MsKeyboardFilter service is running..."
    Set-PostRebootTask
    Write-Log "Post-reboot task created successfully"

    # 4. Reboot
    Write-Log "Rebooting system in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
catch {
    Write-Log "An error occurred: $_"
    exit 1
}
finally {
    Write-Log "Script execution completed"
}
