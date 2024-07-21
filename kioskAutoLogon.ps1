# Simplified Autopilot Kiosk Auto-Logon Setup Script
# This script sets the auto-logon registry keys for kiosk PCs during Autopilot.

$logFile = "C:\Windows\Logs\KioskAutoLogon.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

try {
    Write-Log "Starting Autopilot Kiosk Auto-Logon Setup"

    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    # Set AutoAdminLogon
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
    Write-Log "Set AutoAdminLogon to 1"

    # Set DefaultUsername
    Set-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -Value "kioskUser0" -Type String -Force
    Write-Log "Set DefaultUsername to kioskUser0"

    Write-Log "Kiosk auto-logon configuration completed successfully"
}
catch {
    Write-Log "Error occurred during setup: $_"
}
