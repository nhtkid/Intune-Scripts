# Improved Kiosk Auto-Logon Detection Script

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
    
    # Check if the keys exist and get their values
    $autoAdminLogon = if (Test-Path -Path $winlogonPath -PathType Container) {
        (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue).AutoAdminLogon
    } else { $null }

    $defaultUsername = if (Test-Path -Path $winlogonPath -PathType Container) {
        (Get-ItemProperty -Path $winlogonPath -Name "DefaultUsername" -ErrorAction SilentlyContinue).DefaultUsername
    } else { $null }

    # Log the actual state
    Write-Log "AutoAdminLogon value: $(if ($null -eq $autoAdminLogon) { 'Missing' } else { $autoAdminLogon })"
    Write-Log "DefaultUsername value: $(if ($null -eq $defaultUsername) { 'Missing' } else { $defaultUsername })"

    if ($autoAdminLogon -ne "1" -or $defaultUsername -ne "kioskUser0") {
        Write-Log "Kiosk auto-logon is not correctly configured. Remediation needed."
        exit 1  # Non-compliant, will trigger remediation
    } else {
        Write-Log "Kiosk auto-logon is correctly configured."
        exit 0  # Compliant
    }
}
catch {
    Write-Log "Error occurred: $_"
    exit 1  # Non-compliant, will trigger remediation
}
finally {
    Write-Log "Kiosk Auto-Logon detection completed"
}
