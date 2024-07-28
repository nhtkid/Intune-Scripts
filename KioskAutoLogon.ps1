# This script will remediate two missing registry keys that prevents Kiosk PC auto-logon.
# It will also try to execute after the user is logged on.
# Define the log file path
$logFile = "C:\Windows\Logs\KioskAutoLogon.log"

# Function to write log messages to the log file
function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

# Function to add a command to the RunOnce registry key
function Add-ToRunOnce {
    param($command)
    $runOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $runOnceKey = Get-Item -Path $runOncePath -ErrorAction SilentlyContinue
    if (-not $runOnceKey) {
        New-Item -Path $runOncePath -Force | Out-Null
    }
    $runOnceValueName = "KioskAutoLogonSetup"
    Set-ItemProperty -Path $runOncePath -Name $runOnceValueName -Value $command -Type String -Force
}

try {
    # Write a log message indicating that the script has started
    Write-Log "Starting Autopilot Kiosk Auto-Logon Setup"

    # Define the registry path for the Winlogon settings
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    # Get the current values of the AutoAdminLogon and DefaultUsername registry keys
    $autoAdminLogon = (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue).AutoAdminLogon
    $defaultUsername = (Get-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -ErrorAction SilentlyContinue).DefaultUsername

    # Check if the AutoAdminLogon key is set to "1" and the DefaultUsername key is set to "kioskUser0"
    if ($autoAdminLogon -eq "1" -and $defaultUsername -eq "kioskUser0") {
        # Write a log message indicating that the auto-logon is already correctly configured
        Write-Log "Auto-logon already correctly configured. No changes needed."
    } else {
        # Write a log message indicating that the auto-logon is not correctly configured
        Write-Log "Auto-logon not correctly configured. Setting required keys."

        # Set the AutoAdminLogon key to "1" and the DefaultUsername key to "kioskUser0"
        Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Set-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -Value "kioskUser0" -Type String -Force

        # Write a log message indicating that the registry keys have been created/updated
        Write-Log "Created/Updated AutoAdminLogon and DefaultUsername keys."

        # Add the script to the RunOnce registry key to ensure that it runs again after the kioskUser0's sign in process
        $scriptPath = $MyInvocation.MyCommand.Definition
        $command = "powershell -ExecutionPolicy Bypass -File ""$scriptPath"""
        Add-ToRunOnce -command $command
    }

    # Check if the script was called by the RunOnce registry key
    $runOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $runOnceValueName = "KioskAutoLogonSetup"
    $runOnceValue = (Get-ItemProperty -Path $runOncePath -Name $runOnceValueName -ErrorAction SilentlyContinue).$runOnceValueName
    if ($runOnceValue) {
        # Write a log message indicating that the script was called by the RunOnce registry key
        Write-Log "Script was called by the RunOnce registry key. Exiting."

        # Remove the script from the RunOnce registry key
        Remove-ItemProperty -Path $runOncePath -Name $runOnceValueName -ErrorAction SilentlyContinue

        # Exit the script without making any changes to the registry keys
        exit 0
    }

    # Write a log message indicating that the script has completed successfully
    Write-Log "Kiosk auto-logon configuration completed successfully"
}
catch {
    # Write a log message indicating that an error occurred during setup
    Write-Log "Error occurred during setup: $_"
}
