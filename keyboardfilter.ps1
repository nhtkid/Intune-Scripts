#   This script disables key combos through Windows PowerShell on the local computer.
#   It also logs the execution to a file in C:\Windows\logs.

# Define the log file path
$logFile = "C:\Windows\logs\keyboard_filter_block.log"

# Function to write log messages
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $message" | Out-File -Append -FilePath $logFile
}

# Function to disable a predefined key
function Disable-Predefined-Key($Id) {
    $predefined = Get-WMIObject -class WEKF_PredefinedKey -Namespace root\standardcimv2\embedded |
            where { $_.Id -eq "$Id" }

    if ($predefined) {
        $predefined.Enabled = 0
        $predefined.Put() | Out-Null
        Write-Log "Disabled $Id"
    } else {
        Write-Log "$Id is not a valid predefined key"
    }
}

# Function to disable a custom key
function Disable-Custom-Key($Id) {
    $custom = Get-WMIObject -class WEKF_CustomKey -Namespace root\standardcimv2\embedded |
            where { $_.Id -eq "$Id" }

    if ($custom) {
        $custom.Enabled = 0
        $custom.Put() | Out-Null
        Write-Log "Disabled Custom Filter $Id."
    } else {
        Write-Log "$Id is not a valid custom key"
    }
}

# Function to disable a scancode
function Disable-Scancode($Modifiers, [int]$Code) {
    $scancode = Get-WMIObject -class WEKF_Scancode -Namespace root\standardcimv2\embedded |
            where { ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code) }

    if($scancode) {
        $scancode.Enabled = 0
        $scancode.Put() | Out-Null
        Write-Log "Disabled Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
    } else {
        Write-Log "Custom Scancode {0}+{1:X4} is not a valid scancode" -f $Modifiers, $Code
    }
}

# Log that the script has started
Write-Log "Script started"

# Disable the specified key combinations
Disable-Predefined-Key "Ctrl+Alt+Del"
Disable-Predefined-Key "Ctrl+Esc"
Disable-Custom-Key "Ctrl+V"
Disable-Custom-Key "Numpad0"
Disable-Custom-Key "Shift+Numpad1"
Disable-Custom-Key "%"
Disable-Scancode "Ctrl" 37

# Disable the Windows key
Disable-Predefined-Key "Windows"

# Remove the default breakout key configuration
$settings = Get-WMIObject -class WEKF_Settings -Namespace root\standardcimv2\embedded
$settings.BreakoutKey = ""
$settings.Put() | Out-Null
Write-Log "Removed the default Breakout key configuration."

# Log that the script has finished
Write-Log "Script finished"
