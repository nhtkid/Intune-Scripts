# Corrected Autopilot Kiosk Auto-Logon Setup Script
# This script checks for auto-logon registry keys and creates/updates them if needed during Autopilot.

$logFile = "C:\Windows\Logs\KioskAutoLogon.log"

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

try {
    Write-Log "Starting Autopilot Kiosk Auto-Logon Setup"

    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $autoAdminLogon = (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue).AutoAdminLogon
    $defaultUsername = (Get-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -ErrorAction SilentlyContinue).DefaultUsername

    if ($autoAdminLogon -eq "1" -and $defaultUsername -eq "kioskUser0") {
        Write-Log "Auto-logon already correctly configured. No changes needed."
    } else {
        Write-Log "Auto-logon not correctly configured. Setting required keys."
        
        Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Set-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -Value "kioskUser0" -Type String -Force
        
        Write-Log "Created/Updated AutoAdminLogon and DefaultUsername keys."
    }

    Write-Log "Kiosk auto-logon configuration completed successfully"
}
catch {
    Write-Log "Error occurred during setup: $_"
}
