# Kiosk Auto-Logon Detection Script
# This script checks if the auto-logon registry keys are set correctly for kiosk PCs.
# It will trigger remediation if EITHER key is missing or incorrect.

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

$autoAdminLogon = (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue).AutoAdminLogon
$defaultUsername = (Get-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -ErrorAction SilentlyContinue).DefaultUsername

if ($autoAdminLogon -ne "1" -or $defaultUsername -ne "kioskUser0") {
    Write-Output "Kiosk auto-logon is not correctly configured. Remediation needed."
    exit 1  # Non-compliant, will trigger remediation
} else {
    Write-Output "Kiosk auto-logon is correctly configured."
    exit 0  # Compliant
}
