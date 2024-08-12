# Script to install or remove Windows optional features
# This script will install "Custom Logon" and "Keyboard Filter" under the Device Lockdown features,
# and remove "Windows Media Player Legacy" under the Media Feature, and "Internet Explorer 11".
# A log file will be created under C:\Windows\Logs\ folder to record the output of the script.

# Define the log file path
$logFile = "C:\Windows\Logs\WindowsCapabilityInstallRemove.log"

# Define the features to install or remove
$featuresToInstall = @("DeviceLockdown-CustomLogon", "DeviceLockdown-KeyboardFilter")
$featuresToRemove = @("Media-LegacyComponents", "Internet-Explorer-Optional-amd64")

# Install the features
foreach ($feature in $featuresToInstall) {
    Write-Host "Checking if feature: $feature is installed"
    if (!(Get-WindowsCapability -Online | Where-Object { $_.Name -eq $feature -and $_.State -eq "Installed" })) {
        Write-Host "Installing feature: $feature"
        Add-WindowsCapability -Online -Name $feature | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "Feature: $feature is already installed"
    }
}

# Remove the features
foreach ($feature in $featuresToRemove) {
    Write-Host "Checking if feature: $feature is installed"
    if (Get-WindowsCapability -Online | Where-Object { $_.Name -eq $feature -and $_.State -eq "Installed" }) {
        Write-Host "Removing feature: $feature"
        Remove-WindowsCapability -Online -Name $feature | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "Feature: $feature is not installed"
    }
}

# Force a reboot
Write-Host "Forcing a reboot to complete the installation or removal of features."
Restart-Computer -Force
