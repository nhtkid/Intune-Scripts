# Simplified Keyboard Filter Configuration Script for Kiosk Devices

# Log file path
$LogPath = "C:\Windows\Logs\KeyboardFilterBlock.log"

# Function to write to log file
function Write-KioskLog {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append
}

# Function to enable predefined keys
function Enable-Predefined-Key {
    param ([string]$Id)
    $predefined = Get-WmiObject -Namespace root\standardcimv2\embedded -Class WEKF_PredefinedKey | 
                  Where-Object { $_.Id -eq $Id }
    if ($predefined) {
        $predefined.Enabled = 1
        $predefined.Put() | Out-Null
        Write-KioskLog "Enabled predefined key: $Id"
    } else {
        Write-KioskLog "WARNING: $Id is not a valid predefined key"
    }
}

# Start logging
Write-KioskLog "Script execution started"

try {
    # Enable Keyboard Filter feature
    Write-KioskLog "Enabling Keyboard Filter feature"
    Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart
    Write-KioskLog "Keyboard Filter feature enabled successfully"

    # Configure Keyboard Filter settings
    $settings = Get-WmiObject -Namespace root\standardcimv2\embedded -Class WEKF_Settings
    $settings.IsAdminConfigured = $true
    $settings.IsFilterEnabled = $true
    $settings.Put() | Out-Null
    Write-KioskLog "Configured Keyboard Filter settings"

    # Enable specific key combinations
    $keysToBlock = @("Windows", "Ctrl+Alt+Del", "Ctrl+Esc", "Ctrl+Shift+Esc", "Alt+Tab", "Alt+Esc")
    foreach ($key in $keysToBlock) {
        Enable-Predefined-Key $key
    }

    # Disable the breakout key
    $settings.BreakoutKeyScanCode = 0
    $settings.Put() | Out-Null
    Write-KioskLog "Disabled breakout key"

    Write-KioskLog "Keyboard Filter configuration completed successfully"

    # Schedule a restart
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
              -Argument '-NoProfile -WindowStyle Hidden -Command "Restart-Computer -Force"'
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "RestartAfterKeyboardFilter" `
                           -Description "Restart after Keyboard Filter configuration" -Principal $principal
    Write-KioskLog "Scheduled restart in 1 minute"

} catch {
    Write-KioskLog "ERROR: Script failed with the following error: $_"
    exit 1
}

Write-KioskLog "Script execution completed"
