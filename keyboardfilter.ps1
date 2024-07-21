# Keyboard Filter Configuration Script for Kiosk Devices to block common key combos
# License: MIT (https://opensource.org/licenses/MIT)

param (
    [String] $ComputerName
)

$logFile = "C:\Windows\Logs\KeyboardFilterSetup.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
    Write-Host $message
}

$CommonParams = @{"namespace"="root\standardcimv2\embedded"}
$CommonParams += $PSBoundParameters

function Enable-Predefined-Key($Id) {
    $predefined = Get-WmiObject -class WEKF_PredefinedKey @CommonParams |
        where {
            $_.Id -eq "$Id"
        }
    if ($predefined) {
        $predefined.Enabled = 1
        $predefined.Put() | Out-Null
        Write-Log "Enabled Predefined Key: $Id"
    } else {
        Write-Log "Warning: $Id is not a valid predefined key"
    }
}

function Enable-Custom-Key($Id) {
    $custom = Get-WmiObject -class WEKF_CustomKey @CommonParams |
        where {
            $_.Id -eq "$Id"
        }
    if ($custom) {
        $custom.Enabled = 1
        $custom.Put() | Out-Null
        Write-Log "Enabled Custom Key: $Id"
    } else {
        Set-WmiInstance -class WEKF_CustomKey -argument @{Id="$Id"} @CommonParams | Out-Null
        Write-Log "Added Custom Key: $Id"
    }
}

function Enable-Scancode($Modifiers, [int]$Code) {
    $scancode = Get-WmiObject -class WEKF_Scancode @CommonParams |
        where {
            ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code)
        }
    if($scancode) {
        $scancode.Enabled = 1
        $scancode.Put() | Out-Null
        Write-Log "Enabled Scancode: $Modifiers+$($Code.ToString("X4"))"
    } else {
        Set-WmiInstance -class WEKF_Scancode -argument @{Modifiers="$Modifiers"; Scancode=$Code} @CommonParams | Out-Null
        Write-Log "Added Scancode: $Modifiers+$($Code.ToString("X4"))"
    }
}

try {
    Write-Log "Starting Keyboard Filter Setup"

    # Check if Keyboard Filter feature is installed
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter"
    if ($feature.State -ne "Enabled") {
        Write-Log "Keyboard Filter feature not installed. Installing now..."
        $result = Enable-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter" -All -NoRestart
        if ($result.RestartNeeded) {
            Write-Log "Restart required after installing Keyboard Filter feature. Script will exit."
            exit 3 # Exit code 3 indicates restart needed
        }
    }
    Write-Log "Keyboard Filter feature is installed"

    # Configure Keyboard Filter settings
    $settings = Get-WmiObject -Namespace "root\standardcimv2\embedded" -Class WEKF_Settings
    $settings.BreakoutKeyScanCode = 0  # Disable the breakout key
    $settings.Put() | Out-Null
    Write-Log "Configured Keyboard Filter settings"

    # Enable predefined key filters
    $predefinedKeys = @(
        "Windows", "Ctrl+Alt+Del", "Ctrl+Esc", "Alt+Tab", "Alt+Esc",
        "Ctrl+Shift+Esc", "Win+L", "Win+R", "Win+E", "Win+X", "Win+D"
    )
    foreach ($key in $predefinedKeys) {
        Enable-Predefined-Key $key
    }

    # Enable custom key filters
    $customKeys = @(
        "Ctrl+V", "Ctrl+C", "Ctrl+X", "Ctrl+A", "Ctrl+Z", 
        "Win+M", "Win+P", "Win+S", "Win+I"
    )
    foreach ($key in $customKeys) {
        Enable-Custom-Key $key
    }

    # Enable scancode filters (example)
    Enable-Scancode "Ctrl" 37

    Write-Log "Keyboard Filter configuration completed successfully"
    exit 0 # Success
}
catch {
    Write-Log "Error occurred during setup: $_"
    exit 1 # Failure
}
