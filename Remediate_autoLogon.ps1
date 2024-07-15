# Kiosk Auto-Logon Remediation Script
# This script sets the auto-logon registry keys for kiosk PCs.

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

try {
    # Set AutoAdminLogon to 1 (enable auto-logon)
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force

    # Set the DefaultUsername to kioskUser0
    Set-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -Value "kioskUser0" -Type String -Force

    Write-Output "Kiosk auto-logon has been configured successfully."
    exit 0  # Success
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Output "Failed to configure kiosk auto-logon: $errorMessage"
    exit 1  # Failure
}
