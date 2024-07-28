# Set the log file path
$logFile = "C:\Windows\Logs\KeyboardFilterScript.log"

# Check if the keyboard filter feature is installed
if (-not (Get-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter")) {
    # Enable the keyboard filter feature
    Enable-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter" -NoRestart

    # Log the installation and reboot advice with a timestamp
    "[$(Get-Date)] Keyboard filter feature was not installed. It has been installed, but a system reboot is required for the changes to take effect." | Out-File -Append $logFile
} else {
    # Log that the keyboard filter feature is already installed with a timestamp
    "[$(Get-Date)] Keyboard filter feature is already installed." | Out-File -Append $logFile
}

# Define the common parameters for WMI operations
$CommonParams = @{"namespace"="root\standardcimv2\embedded"}
$CommonParams += $PSBoundParameters

function Enable-Predefined-Key($Id) {
    # Use Get-WMIObject to enumerate all WEKF_PredefinedKey instances,
    # filter against key value "Id", and set that instance's "Enabled"
    # property to 1/true.

    $predefined = Get-WMIObject -class WEKF_PredefinedKey @CommonParams |
        where {
            $_.Id -eq "$Id"
        };

    if ($predefined) {
        $predefined.Enabled = 1
        $predefined.Put() | Out-Null
        "[$(Get-Date)] Blocked $Id" | Out-File -Append $logFile
    } else {
        "[$(Get-Date)] $Id is not a valid predefined key" | Out-File -Append $logFile
    }
}

function Enable-Custom-Key($Id) {
    # Use Get-WMIObject to enumerate all WEKF_CustomKey instances,
    # filter against key value "Id", and set that instance's "Enabled"
    # property to 1/true.
    # In the case that the Custom instance does not exist, add a new
    # instance of WEKF_CustomKey using Set-WMIInstance.

    $custom = Get-WMIObject -class WEKF_CustomKey @CommonParams |
        where {
            $_.Id -eq "$Id"
        };

    if ($custom) {
        $custom.Enabled = 1
        $custom.Put() | Out-Null
        "[$(Get-Date)] Blocked Custom Filter $Id." | Out-File -Append $logFile
    } else {
        Set-WMIInstance -class WEKF_CustomKey -argument @{Id="$Id"} @CommonParams | Out-Null
        "[$(Get-Date)] Added Custom Filter $Id." | Out-File -Append $logFile
    }
}

function Enable-Scancode($Modifiers, [int]$Code) {
    # Use Get-WMIObject to enumerate all WEKF_Scancode instances,
    # filter against key values of "Modifiers" and "Scancode", and set
    # that instance's "Enabled" property to 1/true.
    # In the case that the Scancode instance does not exist, add a new
    # instance of WEKF_Scancode using Set-WMIInstance.

    $scancode =
        Get-WMIObject -class WEKF_Scancode @CommonParams |
            where {
                ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code)
            }

    if($scancode) {
        $scancode.Enabled = 1
        $scancode.Put() | Out-Null
        "[$(Get-Date)] Blocked Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code | Out-File -Append $logFile
    } else {
        Set-WMIInstance -class WEKF_Scancode -argument @{Modifiers="$Modifiers"; Scancode=$Code} @CommonParams | Out-Null
        "[$(Get-Date)] Added Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code | Out-File -Append $logFile
    }
}

# Some example uses of the functions defined above.
Enable-Predefined-Key "Ctrl+Alt+Del"
Enable-Predefined-Key "Shift+Ctrl+Esc"
Enable-Predefined-Key "Win+L"
Enable-Predefined-Key "Ctrl+Esc"
Enable-Predefined-Key "Windows"
Enable-Predefined-Key "Alt+F4"
Enable-Custom-Key "%"
Enable-Scancode "Ctrl" 37
