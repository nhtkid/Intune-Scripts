<#
.Synopsis
    This script shows how to use the built in WMI providers to enable and add
    Keyboard Filter rules through Windows PowerShell on the local computer.
.Parameter ComputerName
    Optional parameter to specify a remote machine that this script should
    manage.  If not specified, the script will execute all WMI operations
    locally.
#>
param (
    [String] $ComputerName
)

# Define the log file path
$logFile = "C:\Windows\logs\keyboard_filter_script.log"

# Function to write log messages
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $message" | Out-File -Append -FilePath $logFile
}

$CommonParams = @{"namespace"="root\standardcimv2\embedded"}
$CommonParams += $PSBoundParameters

function Enable-Predefined-Key($Id) {
    <#
    .Synposis
        Toggle on a Predefined Key Keyboard Filter Rule
    .Description
        Use Get-WMIObject to enumerate all WEKF_PredefinedKey instances,
        filter against key value "Id", and set that instance's "Enabled"
        property to 1/true.
    .Example
        Enable-Predefined-Key "Ctrl+Alt+Delete"

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

# Log that the script has started
Write-Log "Script started"

# Some example uses of the function defined above.

Enable-Predefined-Key "Ctrl+Alt+Del"
Enable-Predefined-Key "Ctrl+Esc"

# Log that the script has finished
Write-Log "Script finished"
