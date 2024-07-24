# Revised Keyboard Filter Configuration Script for Kiosk Devices

# Log file path
$LogPath = "C:\Windows\Logs\KeyboardFilterConfig.log"

# Function to write to log file
function Write-KioskLog {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append
}

# Common parameters for WMI calls
$CommonParams = @{ "namespace" = "root\standardcimv2\embedded" }

# Function to enable predefined keys
function Enable-Predefined-Key($Id) {
    $predefined = Get-WmiObject -class WEKF_PredefinedKey @CommonParams |
        Where-Object { $_.Id -eq $Id }
    
    if ($predefined) {
        $predefined.Enabled = 1
        $predefined.Put() | Out-Null
        Write-KioskLog "Enabled predefined key: $Id"
    } else {
        Write-KioskLog "WARNING: $Id is not a valid predefined key"
    }
}

# Function to enable custom keys
function Enable-Custom-Key($Id) {
    $custom = Get-WmiObject -class WEKF_CustomKey @CommonParams |
        Where-Object { $_.Id -eq $Id }
    
    if ($custom) {
        $custom.Enabled = 1
        $custom.Put() | Out-Null
    } else {
        Set-WmiInstance -class WEKF_CustomKey -argument @{Id=$Id} @CommonParams | Out-Null
    }
    Write-KioskLog "Enabled custom key: $Id"
}

# Start logging
Write-KioskLog "Script execution started"

try {
    # Enable Keyboard Filter feature
    Write-KioskLog "Enabling Keyboard Filter feature"
    Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart
    Write-KioskLog "Keyboard Filter feature enabled successfully"

    # Configure Keyboard Filter settings
    Write-KioskLog "Configuring Keyboard Filter settings"
    Get-WmiObject -class WEKF_Settings @CommonParams -ErrorAction Stop

    # Enable specific predefined key combinations
    $keysToBlock = @(
        "Windows", "Ctrl+Alt+Del", "Ctrl+Esc", "Ctrl+Shift+Esc",
        "Alt+Tab", "Alt+Esc", "Ctrl+Tab"
    )
    foreach ($key in $keysToBlock) {
        Enable-Predefined-Key $key
    }

    # Enable custom keys
    $customKeysToBlock = @("Ctrl+V", "Ctrl+C", "Ctrl+X")
    foreach ($key in $customKeysToBlock) {
        Enable-Custom-Key $key
    }

    # Disable the breakout key
    $settings = Get-WmiObject -class WEKF_Settings @CommonParams
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
