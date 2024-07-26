<#
.Synopsis
    This script shows how to use the built in WMI providers to enable and add
    keyboard filter rules through Windows PowerShell on the local computer.
    It also logs the execution to a file in C:\Windows\logs.
.Parameter ComputerName
    Optional parameter to specify a remote machine that this script should
    manage.  If not specified, the script will execute all WMI operations
    locally.
#>
param (
    [String] $ComputerName
)

$CommonParams = @{"namespace"="root\standardcimv2\embedded"}
$CommonParams += $PSBoundParameters

# Define the log file path
$logFile = "C:\Windows\logs\keyboard_filter_script.log"

# Function to write log messages
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $message" | Out-File -Append -FilePath $logFile
}

function Enable-Predefined-Key($Id) {
    <#
    .Synopsis
        Toggle on a Predefined Key keyboard filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_PredefinedKey instances,
        filter against key value "Id", and set that instance's "Enabled"
        property to 1/true.
    .Example
        Enable-Predefined-Key "Ctrl+Alt+Del"
        Enable CAD filtering
    #>

    $predefined = Get-WMIObject -class WEKF_PredefinedKey @CommonParams |
            where {
                $_.Id -eq "$Id"
            };

    if ($predefined) {
            $predefined.Enabled = 1;
            $predefined.Put() | Out-Null;
            Write-Log "Enabled $Id"
        } else {
            Write-Log "$Id is not a valid predefined key"
        }
}

function Enable-Custom-Key($Id) {
    <#
    .Synopsis
        Toggle on a Custom Key keyboard filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_CustomKey instances,
        filter against key value "Id", and set that instance's "Enabled"
        property to 1/true.

    In the case that the Custom instance does not exist, add a new
        instance of WEKF_CustomKey using Set-WMIInstance.
    .Example
        Enable-Custom-Key "Ctrl+V"
        Enable filtering of the Ctrl + V sequence.
    #>

    $custom = Get-WMIObject -class WEKF_CustomKey @CommonParams |
            where {
                $_.Id -eq "$Id"
            };

    if ($custom) {
    # Rule exists.  Just enable it.
            $custom.Enabled = 1;
            $custom.Put() | Out-Null;
            Write-Log "Enabled Custom Filter $Id.";

    } else {
            Set-WMIInstance -class WEKF_CustomKey -argument @{Id="$Id"} @CommonParams | Out-Null
            Write-Log "Added Custom Filter $Id.";
        }
}

function Enable-Scancode($Modifiers, [int]$Code) {
    <#
    .Synopsis
        Toggle on a Scancode keyboard filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_Scancode instances,
        filter against key values of "Modifiers" and "Scancode", and set
        that instance's "Enabled" property to 1/true.

    In the case that the Scancode instance does not exist, add a new
        instance of WEKF_Scancode using Set-WMIInstance.
    .Example
        Enable-Scancode "Ctrl" 37
        Enable filtering of the Ctrl + keyboard scancode 37 (base-10)
        sequence.
    #>

    $scancode =
            Get-WMIObject -class WEKF_Scancode @CommonParams |
                where {
                    ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code)
                }

    if($scancode) {
            $scancode.Enabled = 1
            $scancode.Put() | Out-Null
            Write-Log "Enabled Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
        } else {
            Set-WMIInstance -class WEKF_Scancode -argument @{Modifiers="$Modifiers"; Scancode=$Code} @CommonParams | Out-Null

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

# Some example uses of the functions defined above.
Enable-Predefined-Key "Ctrl+Alt+Del"
Enable-Predefined-Key "Ctrl+Esc"
Enable-Custom-Key "Ctrl+V"
Enable-Custom-Key "Numpad0"
Enable-Custom-Key "Shift+Numpad1"
Enable-Custom-Key "%"
Enable-Scancode "Ctrl" 37

# Block the "Windows" key
Enable-Predefined-Key "Windows"

# Configure a different key for "Breakout" to avoid locking the machine
$settings = Get-WMIObject -class WEKF_Settings @CommonParams
$settings.BreakoutKey = "Alt+Ctrl+Esc"
$settings.Put() | Out-Null
Write-Log "Configured Alt+Ctrl+Esc as the Breakout key."

# Log that the script has finished
Write-Log "Script finished"
