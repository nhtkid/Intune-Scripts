<#
.SYNOPSIS
    Installs the Windows Keyboard Filter feature if needed, initiates a reboot, and sets up auto-start of the service after reboot.
.DESCRIPTION
    This script checks for the Windows Keyboard Filter feature, installs it if not present,
    initiates a system reboot, and sets up a scheduled task to configure the service after reboot.
    It includes error handling and logging for each step of the process.
#>

# Set log file path
$logPath = "C:\Windows\Logs\KeyboardFilterSetup.log"

# Function to write log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Function to check if running with admin privileges
function Test-AdminPrivileges {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

    # Check for admin privileges
    if (-not (Test-AdminPrivileges)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }

    # 1. Check and install feature if necessary
    $feature = "Client-KeyboardFilter"
    $featureState = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction Stop).State
    if ($featureState -eq 'Disabled') {
        Write-Log "Installing $feature feature..."
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction Stop
        Write-Log "$feature feature installed successfully"
    } else {
        Write-Log "$feature feature is already installed"
    }

    # 2. Set up post-reboot task
    Write-Log "Setting up post-reboot task to configure MsKeyboardFilter service..."
    Set-PostRebootTask
    Write-Log "Post-reboot task created successfully"

    # 3. Reboot
    Write-Log "Rebooting system in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
    exit 1
}
finally {
    Write-Log "Script execution completed"
}
