# Kiosk Auto-Logon Registry Script with Enhanced Error Logging
# This script sets two registry keys to enable auto-logon for kiosk PCs and provides detailed error logging.

$logFile = "C:\Windows\Logs\KioskAutoLogonLog.txt"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, [string]$Value)
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -ErrorAction Stop
        Write-Log "Successfully set $Name to $Value"
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error setting $Name: $errorMessage"
        return $false
    }
}

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Write-Log "Script execution started"

$success = $true

# Set AutoAdminLogon to 1 (enable auto-logon)
if (-not (Set-RegistryValue -Path $winlogonPath -Name "AutoAdminLogon" -Value "1")) {
    $success = $false
}

# Set the DefaultUsername to kioskUser0
if (-not (Set-RegistryValue -Path $winlogonPath -Name "DefaultUsername" -Value "kioskUser0")) {
    $success = $false
}

if ($success) {
    Write-Log "Auto-logon configuration completed successfully."
    exit 0  # Success exit code
}
else {
    Write-Log "Auto-logon configuration failed. Check previous error messages for details."
    exit 1  # Failure exit code
}
