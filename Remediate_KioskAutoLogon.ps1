# Improved Kiosk Auto-Logon Remediation Script

$logFile = "C:\Windows\Logs\KioskAutoLogonRemediation.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
    Write-Output $message
}

try {
    Write-Log "Starting Kiosk Auto-Logon remediation"

    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    # Ensure the Winlogon key exists
    if (-not (Test-Path $winlogonPath)) {
        New-Item -Path $winlogonPath -Force | Out-Null
        Write-Log "Created Winlogon registry key"
    }

    # Set AutoAdminLogon
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
    Write-Log "Set AutoAdminLogon to 1"

    # Set DefaultUsername
    Set-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -Value "kioskUser0" -Type String -Force
    Write-Log "Set DefaultUsername to kioskUser0"

    Write-Log "Kiosk auto-logon has been configured successfully."
    exit 0  # Success
}
catch {
    Write-Log "Error occurred during remediation: $_"
    exit 1  # Failure
}
finally {
    Write-Log "Kiosk Auto-Logon remediation completed"
}
