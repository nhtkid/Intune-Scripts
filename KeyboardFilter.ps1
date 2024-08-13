# Define the log file path
$logFile = "C:\Windows\logs\EnableKeyboardFilter.log"

# Function to write log messages
function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $message" | Out-File -Append -FilePath $logFile
}

# Check if Keyboard Filter feature is installed
$keyboardFilterFeature = Get-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter

if ($keyboardFilterFeature.State -ne "Enabled") {
    # Install Keyboard Filter feature
    Write-Log "Keyboard Filter feature is not installed. Installing..."
    Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart -OutVariable result

    if ($result.RestartNeeded -eq $true) {
        Write-Log "Restart is needed after installing Keyboard Filter feature."
    }
} else {
    Write-Log "Keyboard Filter feature is already installed."
}

# Ensure the Keyboard Filter service is set to Automatic and started
Set-Service -Name MsKeyboardFilter -StartupType Automatic
Start-Service -Name MsKeyboardFilter
Write-Log "Microsoft Keyboard Filter service set to Automatic and started."

# Add a 100-second delay
Start-Sleep -Seconds 100

# Function to enable a predefined key
function Enable-Predefined-Key($Id) {
    try {
        $predefined = Get-WMIObject -class WEKF_PredefinedKey -Namespace root\standardcimv2\embedded |
                Where-Object { $_.Id -eq "$Id" }

        if ($predefined) {
            $predefined.Enabled = 1
            $predefined.Put() | Out-Null
            Write-Log "Blocked $Id"
        } else {
            Write-Log "$Id is not a valid predefined key"
        }
    } catch {
        Write-Log "Error blocking predefined key $Id $_"
    }
}

# Function to enable a custom key
function Enable-Custom-Key($Id) {
    try {
        $custom = Get-WMIObject -class WEKF_CustomKey -Namespace root\standardcimv2\embedded |
                Where-Object { $_.Id -eq "$Id" }

        if ($custom) {
            $custom.Enabled = 1
            $custom.Put() | Out-Null
            Write-Log "Blocked Custom Filter $Id."
        } else {
            Set-WMIInstance -class WEKF_CustomKey -argument @{Id="$Id"} -Namespace root\standardcimv2\embedded | Out-Null
            Write-Log "Added Custom Filter $Id."
        }
    } catch {
        Write-Log "Error blocking custom key $Id $_"
    }
}

# Function to enable a scancode
function Enable-Scancode($Modifiers, [int]$Code) {
    try {
        $scancode = Get-WMIObject -class WEKF_Scancode -Namespace root\standardcimv2\embedded |
                Where-Object { ($_.Modifiers -eq $Modifiers) -and ($_.Scancode -eq $Code) }

        if($scancode) {
            $scancode.Enabled = 1
            $scancode.Put() | Out-Null
            Write-Log "Blocked Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
        } else {
            Set-WMIInstance -class WEKF_Scancode -argument @{Modifiers="$Modifiers"; Scancode=$Code} -Namespace root\standardcimv2\embedded | Out-Null
            Write-Log "Added Custom Scancode {0}+{1:X4}" -f $Modifiers, $Code
        }
    } catch {
        Write-Log "Error blocking scancode $Modifiers+$Code $_"
    }
}

# Log that the script has started
Write-Log "Script started"

# Enable the specified key combinations
Enable-Predefined-Key "Ctrl+Alt+Del"
Enable-Predefined-Key "Windows"
Enable-Predefined-Key "Escape"
Enable-Predefined-Key "Alt+F4"
Enable-Predefined-Key "Ctrl+Esc"
Enable-Predefined-Key "Alt+Tab"
Enable-Custom-Key "Ctrl+V"
Enable-Scancode "Ctrl" 37

# Log that the script has finished
Write-Log "Script finished"
