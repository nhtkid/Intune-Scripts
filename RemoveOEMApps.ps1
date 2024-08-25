# Define the log file path
$logFile = "C:\Windows\Logs\AppRemoval.log"

# Get all installed packages that contain "Dell" in their name
$dellPackages = Get-AppxPackage | Where-Object { $_.Name -like "*Dell*" }

# Check for each package and remove if it matches the known Dell package names
foreach ($package in $dellPackages) {
    if ($package.Name -like "*CommandUpdate*" -or $package.Name -like "*SupportAssistant*") {
        # Package is a known Dell package, so remove it
        Write-Host "Removing $($package.Name)..."
        Remove-AppxPackage -Package $package.PackageFullName
        Write-Host "$($package.Name) has been removed."

        # Write to the log file
        "$(Get-Date): $($package.Name) has been removed." | Out-File -FilePath $logFile -Append
    } else {
        # Package is not a known Dell package
        Write-Host "$($package.Name) is not a known Dell package."

        # Write to the log file
        "$(Get-Date): $($package.Name) is not a known Dell package." | Out-File -FilePath $logFile -Append
    }
}
