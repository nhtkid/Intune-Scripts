# Set the log file path
$logFile = "C:\Windows\Logs\UpdateInstall.log"

# Check for pending updates
$session = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$searchResult = $searcher.Search("IsInstalled=0 and Type='Software'")

# If there are pending updates, install them
if ($searchResult.Updates.Count -gt 0) {
    Write-Host "Pending updates found. Installing..." | Out-File -FilePath $logFile -Append
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $searchResult.Updates
    $downloader.Download()

    $installationResult = $session.CreateUpdateInstaller().Install()
    Write-Host "Installation Result: " $installationResult.ResultCode | Out-File -FilePath $logFile -Append

    # Reboot if required
    if ($installationResult.RebootRequired) {
        Write-Host "Rebooting..." | Out-File -FilePath $logFile -Append
        Restart-Computer
    }
} else {
    Write-Host "No pending updates found." | Out-File -FilePath $logFile -Append
}
