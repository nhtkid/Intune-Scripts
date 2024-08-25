# Script to remove Dell Command and Support Assistant applications
# Log file path
$logFile = "C:\Windows\Logs\DellAppRemoval.log"

# Function to log messages
function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

# Function to check if app name matches the criteria
function Match-AppName {
    param($name, $criteria)
    foreach ($criterion in $criteria) {
        if ($criterion.Count -eq 1) {
            if ($name -like "*$($criterion[0])*") { return $true }
        } elseif ($criterion.Count -eq 2) {
            if ($name -like "*$($criterion[0])*" -and $name -like "*$($criterion[1])*") { return $true }
        }
    }
    return $false
}

# Function to uninstall Win32 application
function Uninstall-Win32App {
    param($criteria)
    Write-Log "Searching for Win32 apps matching criteria"
    $apps = Get-Package | Where-Object { Match-AppName $_.Name $criteria }
    foreach ($app in $apps) {
        Write-Log "Attempting to uninstall Win32 app: $($app.Name)"
        try {
            $app | Uninstall-Package -Force -ErrorAction Stop
            Write-Log "Successfully uninstalled Win32 app: $($app.Name)"
        }
        catch {
            Write-Log "Failed to uninstall Win32 app: $($app.Name). Error: $($_.Exception.Message)"
        }
    }
}

# Function to uninstall AppX package
function Uninstall-AppxPackage {
    param($criteria)
    Write-Log "Searching for AppX packages matching criteria"
    $packages = Get-AppxPackage | Where-Object { Match-AppName $_.Name $criteria }
    foreach ($package in $packages) {
        Write-Log "Attempting to uninstall AppX package: $($package.Name)"
        try {
            $package | Remove-AppxPackage -ErrorAction Stop
            Write-Log "Successfully uninstalled AppX package: $($package.Name)"
        }
        catch {
            Write-Log "Failed to uninstall AppX package: $($package.Name). Error: $($_.Exception.Message)"
        }
    }
}

# Main script execution
Write-Log "Starting Dell application removal script"

# Criteria for Win32 apps to remove (each sub-array represents AND condition between words)
$win32Criteria = @(
    @("Dell", "Command"),
    @("Dell", "Support"),
    @("Dell", "Update"),
    @("Dell", "Optimize")
)

# Criteria for AppX packages to remove
$appxCriteria = @(
    @("DellInc.DellCommand"),
    @("DellInc.DellSupport"),
    @("DellInc.DellUpdate"),
    @("DellInc.DellOptimize"),
    @("Dell", "Command"),
    @("Dell", "Support"),
    @("Dell", "Update"),
    @("Dell", "Optimize")
)

# Remove Win32 apps
Uninstall-Win32App $win32Criteria

# Remove AppX packages
Uninstall-AppxPackage $appxCriteria

Write-Log "Dell application removal script completed"
