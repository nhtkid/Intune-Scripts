<#
.Synopsis
    This script enables keyboard filter rules through Windows PowerShell on the local computer.
    It also logs the execution to a file in C:\Windows\logs.
#>

# Define the log file path
$logFile = "C:\Windows\logs\keyboard_filter_script.log"

# Function to write log messages
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $message" | Out-File -Append -FilePath $logFile
}

# Function to enable a predefined key
function Enable-Predefined-Key($Id) {
    $predefined = Get-WMIObject -class WEKF_PredefinedKey -Namespace root\standardcimv2\embedded |
            where { $_.Id -eq "$Id" }

    if ($predefined) {
        $predefined.Enabled = 1
        $predefined.Put() | Out-Null
        Write-Log "Enabled $Id"
    } else {
        Write-Log "$Id is not a valid predefined key"
    }
}

# Function to enable a custom key
function Enable-Custom-Key($Id) {
    $custom = Get-WMIObject -class WEKF_CustomKey -Namespace root\standardcimv2\embedded |
            where { $_.Id -eq "$Id" }

    if ($custom) {
        $custom.Enabled = 1
        $custom.Put() | Out-Null
        Write-Log "Enabled Custom Filter $Id."
    } else {
        Set-WMIInstance -class WEKF_CustomKey -argument @{Id="$Id"} -Namespace root\standardcimv2\embedded | Out-Null
        Write-Log "Added Custom Filter $Id."
    }
}

# Function to enable a scancode
function Enable-Scancode($Modifiers, [int]$Code) {
    $scancode = Get-WMIObject -class WEKF_Scancode -Namespace root\standardcimv2\embedded |
            where { ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code) }

    if($scancode) {
        $scancode.Enabled = 1
        $scancode.Put() | Out-Null
        Write-Log "Enabled Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
    } else {
        Set-WMIInstance -class WEKF_Scancode -argument @{Modifiers="$Modifiers"; Scancode=$Code} -Namespace root\standardcimv2\embedded | Out-Null
        Write-Log "Added Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
    }
}

# Check if Keyboard Filter feature is installed
$keyboardFilterFeature = Get-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter

if ($keyboardFilterFeature.State -ne "Enabled") {
    # Install Keyboard Filter feature
    Write-Log "Keyboard Filter feature is not installed. Installing..."
    Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart -OutVariable result

    if ($result.RestartNeeded -eq $true) {
        Write-Log "Restart is needed after installing Keyboard Filter feature."
        Restart-Computer -Force
    }
} else {
    Write-Log "Keyboard Filter feature is already installed."
}

# Log that the script has started
Write-Log "Script started"

# Enable the specified key combinations
Enable-Predefined-Key "Ctrl+Alt+Del"
Enable-Predefined-Key "Ctrl+Esc"
Enable-Custom-Key "Ctrl+V"
Enable-Custom-Key "Numpad0"
Enable-Custom-Key "Shift+Numpad1"
Enable-Custom-Key "%"
Enable-Scancode "Ctrl" 37

# Block the Windows key
Enable-Predefined-Key "Windows"

# Log that the script has finished
Write-Log "Script finished"
