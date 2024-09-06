# Define Log Path
$ScriptVersion = "2.0"
$DateTime = [DateTime]::Now.ToString("yyyyMMdd")
$LogFile = "RemoveDellOEMApplications-" + $ScriptVersion + "_" + $DateTime + ".log"
$LogPath = "C:\Windows\Logs"
$OutFile = "$LogPath\$LogFile"
$NewLine = "."

# Start the Logging
Start-Transcript $OutFile -Force

Write-Output -Verbose "--------------------------------"
Write-Output -Verbose "  Uninstall OEM Applications    "
Write-Output -Verbose "--------------------------------"

# Define applications to uninstall
$OEMApplications = @(
    "DellInc.DellOptimizer",
    "Dell Optimizer Service",
    "*Dell*"
)

# Define applications to keep
$OEMApplicationsToKeep = @(
    "Dell Display Manager",
    "Dell PointStick Driver",
    "Dell Peripheral Manager",
    "Dell Pair"
)

$OEMApplicationsToKeep = $OEMApplicationsToKeep -join "|"

ForEach ($OEMApplication in $OEMApplications){
    # Search for applications in registry and AppX
    $RegistryApps = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Select-Object DisplayName, DisplayVersion, QuietUninstallString, UninstallString, PSChildName |
    Where-Object {$_.DisplayName -Like $OEMApplication -And $_.DisplayName -NotMatch $OEMApplicationsToKeep}

    $AppXProvisionedApps = Get-AppxProvisionedPackage -Online |
    Where-Object {$_.DisplayName -Like $OEMApplication -And $_.DisplayName -NotMatch $OEMApplicationsToKeep}

    $AppXPackageApps = Get-AppxPackage -AllUsers |
    Where-Object {$_.Name -Like $OEMApplication -And $_.Name -NotMatch $OEMApplicationsToKeep}

    # Search for W32 apps using Get-Package
    $W32Apps = Get-Package |
    Where-Object {$_.Name -Like $OEMApplication -And $_.Name -NotMatch $OEMApplicationsToKeep}

    # Check if any applications were found
    If (($null -eq $RegistryApps) -and ($null -eq $AppXProvisionedApps) -and ($null -eq $AppXPackageApps) -and ($null -eq $W32Apps)){
        Write-Output "No $OEMApplication Applications found to uninstall."
        Write-Output $NewLine
    } Else {
        # Remove AppX Provisioned Apps
        If ($null -ne $AppXProvisionedApps){
            ForEach ($AppXProvisionedApp in $AppXProvisionedApps){
                $AppXDisplayName = $AppXProvisionedApp.DisplayName
                Write-Output "Uninstalling $AppXDisplayName [AppX Provisioned App]..."
                Try {
                    $AppXProvisionedApp | Remove-ProvisionedAppxPackage -Online -AllUsers -ErrorAction Stop
                    Write-Output "Successfully uninstalled $AppXDisplayName [AppX Provisioned App]."
                }
                Catch {
                    Write-Output "Failed to uninstall $AppXDisplayName [AppX Provisioned App]. Error: $_"
                }
                Write-Output $NewLine
            }
        }

        # Remove AppX Package Apps
        If ($null -ne $AppXPackageApps){
            ForEach ($AppXPackageApp in $AppXPackageApps){
                $AppXName = $AppXPackageApp.Name
                Write-Output "Uninstalling $AppXName [AppX Package]..."
                Try {
                    $AppXPackageApp | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    Write-Output "Successfully uninstalled $AppXName [AppX Package]."
                }
                Catch {
                    Write-Output "Failed to uninstall $AppXName [AppX Package]. Error: $_"
                }
                Write-Output $NewLine
            }
        }

        # Remove W32 apps
        If ($null -ne $W32Apps){
            ForEach ($W32App in $W32Apps){
                $AppName = $W32App.Name
                Write-Output "Uninstalling $AppName [W32 App]..."
                Try {
                    Uninstall-Package -Name $AppName -Force -ErrorAction Stop
                    Write-Output "Successfully uninstalled $AppName [W32 App]."
                }
                Catch {
                    Write-Output "Failed to uninstall $AppName [W32 App]. Error: $_"
                }
                Write-Output $NewLine
            }
        }

        # Stop Dell Optimizer Running Process
        $ProcessToStop = "DellOptimizer"
        $OEMProcesses = Get-Process -ProcessName $ProcessToStop -ErrorAction SilentlyContinue

        If ($null -ne $OEMProcesses){
            Write-Output "Stopping Dell Optimizer Running Processes..."
            While ($null -ne $OEMProcesses){
                ForEach ($OEMProcess in $OEMProcesses){
                    $OEMProcessName = $OEMProcess.ProcessName
                    Write-Output "Stopping $OEMProcessName Process..."
                    Try {
                        Stop-Process -Name $OEMProcessName -Force -ErrorAction Stop
                        Write-Output "Successfully stopped $OEMProcessName Process."
                    }
                    Catch {
                        Write-Output "Failed to stop $OEMProcessName Process. Error: $_"
                    }
                    Start-Sleep -s 5
                    $OEMProcesses = Get-Process -ProcessName $ProcessToStop -ErrorAction SilentlyContinue
                }
            }
            Write-Output $NewLine
        }

        # Stop and Disable Dell Optimizer Running Services
        $ServiceToStop = "Dell Optimizer"
        $OEMServices = Get-WmiObject win32_service |
        Select-Object Name,DisplayName,State,StartMode |
        Where-Object { $_.DisplayName -like $ServiceToStop } |
        Where-Object {$_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"} -ErrorAction SilentlyContinue

        If ($null -ne $OEMServices){
            Write-Output "Stopping and Disabling Dell Optimizer Running Services..."
            While ($null -ne $OEMServices){
                ForEach ($OEMService in $OEMServices){
                    $OEMServiceName = $OEMService.Name
                    $OEMServiceDisplayName = $OEMService.DisplayName
                    $OEMServiceState = $OEMService.State
                    Write-Output "Stopping and Disabling $OEMServiceDisplayName Service..."
                    Try {
                        Set-Service -Name $OEMServiceName -StartupType Disabled -ErrorAction Stop
                        Stop-Service -Name $OEMServiceName -Force -ErrorAction Stop
                        Write-Output "Successfully stopped and disabled $OEMServiceDisplayName Service."
                    }
                    Catch {
                        Write-Output "Failed to stop and disable $OEMServiceDisplayName Service. Error: $_"
                    }
                    Start-Sleep -s 5
                    $OEMServices = Get-WmiObject win32_service |
                    Select-Object Name,DisplayName,State,StartMode |
                    Where-Object { $_.DisplayName -like $ServiceToStop } |
                    Where-Object {$_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"} -ErrorAction SilentlyContinue
                }
            }
            Write-Output $NewLine
        }

        # Remove Registry Apps
        If ($null -ne $RegistryApps){
            ForEach ($RegistryApp in $RegistryApps){
                $AppDisplayName = $RegistryApp.DisplayName
                $AppGUID = $RegistryApp.PSChildName
                Write-Output "Uninstalling $AppDisplayName [Registry App]..."
                Try {
                    If ($null -ne $RegistryApp.QuietUninstallString){
                        & $RegistryApp.QuietUninstallString -ErrorAction Stop
                    } ElseIf ($null -ne $RegistryApp.UninstallString){
                        Start-Process -FilePath $RegistryApp.UninstallString -ArgumentList "/silent" -NoNewWindow -RedirectStandardOutput $null -RedirectStandardError $null -Wait -ErrorAction Stop
                    } Else {
                        Write-Output "Uninstall string not found for $AppDisplayName."
                    }
                    Write-Output "Successfully uninstalled $AppDisplayName [Registry App]."
                }
                Catch {
                    Write-Output "Failed to uninstall $AppDisplayName [Registry App]. Error: $_"
                }
                Write-Output $NewLine
            }
        }
    }
}

# Stop the Logging
Stop-Transcript
