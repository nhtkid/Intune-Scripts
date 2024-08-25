# Define the log file path
$logFile = "C:\Windows\Logs\AppRemoval.log"

# Define the app names to remove
$appNames = @("Command", "SupportAssistant")

# Remove Win32 packages
$win32Packages = Get-Package | Where-Object { $_.Name -match "Dell.*($($appNames -join '|'))" }
foreach ($package in $win32Packages) {
    Write-Host "Removing $($package.Name)..."
    Uninstall-Package -Name $package.Name
    Write-Host "$($package.Name) has been removed."
    "$(Get-Date): $($package.Name) has been removed." | Out-File -FilePath $logFile -Append
}

# Remove UWP packages
$uwpPackages = Get-AppxPackage | Where-Object { $_.Name -match "Dell.*($($appNames -join '|'))" }
foreach ($package in $uwpPackages) {
    Write-Host "Removing $($package.Name)..."
    Remove-AppxPackage -Package $package.PackageFullName
    Write-Host "$($package.Name) has been removed."
    "$(Get-Date): $($package.Name) has been removed." | Out-File -FilePath $logFile -Append
}
