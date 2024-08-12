# Script to install or remove Windows optional features
# This script will install or remove the specified features. To use this script, replace the values in the $featuresToInstall and $featuresToRemove arrays with the names of the features you want to install or remove.
# If the "Client-KeyboardFilter" feature is installed, the script will set the startup type of the KeyboardFilter service to Automatic and start the service.
# A log file will be created under C:\Windows\Logs\ folder to record the output of the script.
# The script will only force a reboot if a feature is installed or removed.

# Define the log file path
$logFile = "C:\Windows\Logs\WindowsCapabilityInstallRemove.log"

# Define the features to install or remove
$featuresToInstall = @("Client-KeyboardFilter", "Client-EmbeddedLogon")
$featuresToRemove = @("Internet-Explorer-Optional-amd64", "WindowsMediaPlayer")

# Initialize a variable to track if a reboot is required
$rebootRequired = $false

# Check if the user provided features to install or remove
if ($featuresToInstall.Count -eq 0 -and $featuresToRemove.Count -eq 0) {
    Write-Host "No features to install or remove. Please replace the values in the $featuresToInstall and $featuresToRemove arrays with the names of the features you want to install or remove."
    exit
}

# Install the features
foreach ($feature in $featuresToInstall) {
    Write-Host "Checking if feature: $feature is installed"
    if (!(Get-WindowsCapability -Online | Where-Object { $_.Name -eq $feature -and $_.State -eq "Installed" })) {
        Write-Host "Installing feature: $feature"
        Add-WindowsCapability -Online -Name $feature | Out-File -FilePath $logFile -Append

        # If the feature is Client-KeyboardFilter, set the startup type of the KeyboardFilter service to Automatic and start the service
        if ($feature -eq "Client-KeyboardFilter") {
            Write-Host "Setting the startup type of the KeyboardFilter service to Automatic"
            Set-Service -Name KeyboardFilter -StartupType Automatic | Out-File -FilePath $logFile -Append
            Write-Host "Starting the KeyboardFilter service"
            Start-Service -Name KeyboardFilter | Out-File -FilePath $logFile -Append
        }

        # Set the reboot flag to true
        $rebootRequired = $true
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

        # Set the reboot flag to true
        $rebootRequired = $true
    } else {
        Write-Host "Feature: $feature is not installed"
    }
}

# Force a reboot if required
if ($rebootRequired) {
    Write-Host "Forcing a reboot to complete the installation or removal of features."
    Restart-Computer -Force
} else {
    Write-Host "No reboot is required."
}
