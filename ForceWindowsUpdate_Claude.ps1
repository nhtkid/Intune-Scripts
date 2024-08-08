# Force installation of pending Windows updates and reboot
# This script assumes updates are already downloaded and pending installation

# Create a log file
$logFile = "C:\Windows\Logs\ForceUpdateInstall.log"
Start-Transcript -Path $logFile -Append

try {
    Write-Output "Starting forced installation of pending updates..."

    # Use wuauclt to initiate the installation of pending updates
    $wuaucltResult = wuauclt /detectnow /updatenow
    Write-Output "wuauclt command executed. Result: $wuaucltResult"

    # Wait for the update process to start and complete (adjust timeout as needed)
    $timeout = 3600 # 1 hour timeout
    $timer = [Diagnostics.Stopwatch]::StartNew()

    while ($timer.Elapsed.TotalSeconds -lt $timeout) {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $pendingCount = $updateSearcher.GetTotalHistoryCount()

        if ($pendingCount -eq 0) {
            Write-Output "No more pending updates found. Installation likely completed."
            break
        }

        Write-Output "Updates still in progress. Waiting..."
        Start-Sleep -Seconds 60 # Check every minute
    }

    if ($timer.Elapsed.TotalSeconds -ge $timeout) {
        Write-Output "Timeout reached. Update process may not have completed."
    }

    Write-Output "Update installation process finished or timed out. Initiating reboot..."
    
    # Force a reboot
    Restart-Computer -Force
}
catch {
    Write-Output "An error occurred: $_"
}
finally {
    Stop-Transcript
}
