# Script to remove specific Dell applications (Command, SupportAssist, Optimizer)
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
    param($name, $keywords)
    return ($keywords[0] -in $name) -and ($keywords[1] -in $name)
}

# Function to uninstall Win32 application
function Uninstall-Win32App {
    param($keywords)
    $apps = Get-Package | Where-Object { Match-AppName $_.Name $keywords }
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
    param($keywords)
    $packages = Get-AppxPackage | Where-Object { Match-AppName $_.Name $keywords }
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

# List of target apps with their keywords
$targetApps = @(
    @("Dell", "Command"),
    @("Dell", "SupportAssist"),
    @("Dell", "Optimizer")
)

# Loop through each target app
foreach ($app in $targetApps) {
    Write-Log "Checking for applications containing keywords: $($app[0]) and $($app[1])"
    
    # Check and uninstall Win32 apps
    $win32Apps = Get-Package | Where-Object { Match-AppName $_.Name $app }
    if ($win32Apps) {
        Write-Log "Found matching Win32 app(s). Attempting to uninstall."
        Uninstall-Win32App $app
    } else {
        Write-Log "No matching Win32 app found."
    }
    
    # Check and uninstall UWP apps
    $uwpApps = Get-AppxPackage | Where-Object { Match-AppName $_.Name $app }
    if ($uwpApps) {
        Write-Log "Found matching UWP app(s). Attempting to uninstall."
        Uninstall-AppxPackage $app
    } else {
        Write-Log "No matching UWP app found."
    }
}

Write-Log "Dell application removal script completed"
