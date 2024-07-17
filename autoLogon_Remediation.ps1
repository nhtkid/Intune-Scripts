# Kiosk Auto-Logon Remediation Script with Error Handling and Logging
# This script sets the auto-logon registry keys for kiosk PCs.
# Logs are written to C:\Windows\Logs\KioskAutoLogonRemediation.log

$logFile = "C:\Windows\Logs\KioskAutoLogonRemediation.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
    Write-Output $message
}

function Set-RegistryValue {
    param($path, $name, $value)
    try {
        Set-ItemProperty -Path $path -Name $name -Value $value -ErrorAction Stop
        Write-Log "Successfully set $name to $value"
    }
    catch {
        throw "Failed to set $name: $_"
    }
}

try {
    Write-Log "Starting Kiosk Auto-Logon remediation"

    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-RegistryValue -path $winlogonPath -name "AutoAdminLogon" -value "1"
    Set-RegistryValue -path $winlogonPath -name "DefaultUsername" -value "kioskUser0"

    Write-Log "Kiosk auto-logon has been configured successfully."
    exit 0  # Success
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Log "Error occurred during remediation: $errorMessage"
    exit 1  # Failure
}
finally {
    Write-Log "Kiosk Auto-Logon remediation completed"
}
