# Define Log Path
$ScriptVersion = "2.1.4"
$DateTime = [DateTime]::Now.ToString("yyyyMMdd")
$LogFile = "RemoveDellOEMApplications-" + $ScriptVersion + "_" + $DateTime + ".log"
$LogPath = "C:\Windows\Logs"
$OutFile = "$LogPath\$LogFile"

# Start the Logging
Start-Transcript $OutFile -Force

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
    } Else {
        # Remove AppX Provisioned Apps
        If ($null -ne $AppXProvisionedApps){
            ForEach ($AppXProvisionedApp in $AppXProvisionedApps){
                $AppXDisplayName = $AppXProvisionedApp.DisplayName
                $AppXPackageFullName = $AppXProvisionedApp.PackageFullName
                Try {
                    $AppXProvisionedApp | Remove-ProvisionedAppxPackage -Online -AllUsers -ErrorAction Stop
                    Write-Output "$AppXDisplayName ($AppXPackageFullName) - Successfully uninstalled [AppX Provisioned App]."
                }
                Catch {
                    Write-Output "$AppXDisplayName ($AppXPackageFullName) - Failed to uninstall [AppX Provisioned App]. Error: $_"
                }
            }
        }

        # Remove AppX Package Apps
        If ($null -ne $AppXPackageApps){
            ForEach ($AppXPackageApp in $AppXPackageApps){
                $AppXName = $AppXPackageApp.Name
                $AppXPackageFullName = $AppXPackageApp.PackageFullName
                Try {
                    $AppXPackageApp | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    Write-Output "$AppXName ($AppXPackageFullName) - Successfully uninstalled [AppX Package]."
                }
                Catch {
                    Write-Output "$AppXName ($AppXPackageFullName) - Failed to uninstall [AppX Package]. Error: $_"
                }
            }
        }

        # Remove W32 apps
        If ($null -ne $W32Apps){
            ForEach ($W32App in $W32Apps){
                $AppName = $W32App.Name
                $AppTagId = $W32App.TagId
                Try {
                    Uninstall-Package -Name $AppName -Force -ErrorAction Stop
                    Write-Output "$AppName ($AppTagId) - Successfully uninstalled [W32 App]."
                }
                Catch {
                    Write-Output "$AppName ($AppTagId) - Failed to uninstall [W32 App]. Error: $_"
                }
            }
        }

        # Remove Registry Apps
        If ($null -ne $RegistryApps){
            ForEach ($RegistryApp in $RegistryApps){
                $AppDisplayName = $RegistryApp.DisplayName
                $AppGUID = $RegistryApp.PSChildName
                Write-Output "Attempting to uninstall: $AppDisplayName ($AppGUID)"
                
                If ($null -ne $RegistryApp.QuietUninstallString) {
                    Write-Output "Using QuietUninstallString: $($RegistryApp.QuietUninstallString)"
                    Try {
                        Invoke-Expression $RegistryApp.QuietUninstallString -ErrorAction Stop
                        Write-Output "$AppDisplayName ($AppGUID) - Successfully uninstalled using QuietUninstallString."
                    }
                    Catch {
                        Write-Output "$AppDisplayName ($AppGUID) - Failed to uninstall using QuietUninstallString. Error: $_"
                    }
                } ElseIf ($null -ne $RegistryApp.UninstallString) {
                    Write-Output "Using UninstallString: $($RegistryApp.UninstallString)"
                    If ($RegistryApp.UninstallString -like "MsiExec.exe*") {
                        $productCode = $RegistryApp.UninstallString -replace ".*({.*}).*", '$1'
                        $uninstallArgs = "/x $productCode /qn"
                        Write-Output "Executing: MsiExec.exe $uninstallArgs"
                        Try {
                            Start-Process "MsiExec.exe" -ArgumentList $uninstallArgs -Wait -NoNewWindow -ErrorAction Stop
                            Write-Output "$AppDisplayName ($AppGUID) - Successfully uninstalled using MsiExec."
                        }
                        Catch {
                            Write-Output "$AppDisplayName ($AppGUID) - Failed to uninstall using MsiExec. Error: $_"
                        }
                    } Else {
                        $uninstallCommand = "$($RegistryApp.UninstallString) /silent"
                        Write-Output "Executing: $uninstallCommand"
                        Try {
                            Invoke-Expression $uninstallCommand -ErrorAction Stop
                            Write-Output "$AppDisplayName ($AppGUID) - Successfully uninstalled using UninstallString with /silent."
                        }
                        Catch {
                            Write-Output "$AppDisplayName ($AppGUID) - Failed to uninstall using UninstallString with /silent. Error: $_"
                        }
                    }
                } Else {
                    Write-Output "$AppDisplayName ($AppGUID) - Uninstall string not found."
                }
            }
        }
    }
}

# Stop the Logging
Stop-Transcript
