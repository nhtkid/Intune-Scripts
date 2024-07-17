# Kiosk Auto-Logon Detection Script with Enhanced Error Logging
# This script checks if the auto-logon registry keys are set correctly for kiosk PCs.
# It will trigger remediation if EITHER key is missing or incorrect.
# Logs are written to C:\Windows\Logs\KioskAutoLogonDetection.log

$logFile = "C:\Windows\Logs\KioskAutoLogonDetection.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
    Write-Output $message
}

try {
    Write-Log "Starting Kiosk Auto-Logon detection"

    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    $autoAdminLogon = (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction Stop).AutoAdminLogon
    $defaultUsername = (Get-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -ErrorAction Stop).DefaultUsername

    Write-Log "AutoAdminLogon value: $autoAdminLogon"
    Write-Log "DefaultUsername value: $defaultUsername"

    if ($autoAdminLogon -ne "1" -or $defaultUsername -ne "kioskUser0") {
        Write-Log "Kiosk auto-logon is not correctly configured. Remediation needed."
        exit 1  # Non-compliant, will trigger remediation
    } else {
        Write-Log "Kiosk auto-logon is correctly configured."
        exit 0  # Compliant
    }
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Log "Error occurred during script execution: $errorMessage"
    exit 2  # Error occurred
}
finally {
    Write-Log "Kiosk Auto-Logon detection completed"
}
