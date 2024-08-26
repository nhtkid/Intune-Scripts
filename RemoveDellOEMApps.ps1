# Define Log Path
$ScriptVersion = "1.5"
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
        Write-Output "All $OEMApplication Applications are Uninstalled."
        Write-Output $NewLine
    } Else {
        # Remove AppX Provisioned Apps
        If ($null -ne $AppXProvisionedApps){
            Write-Output "[ $OEMApplication AppX Provisioned Apps Installed ]"
            ForEach ($AppXProvisionedApp in $AppXProvisionedApps){
                $AppXDisplayName = $AppXProvisionedApp.DisplayName
                Write-Output "$AppXDisplayName [AppX Provisioned App]"
                $AppXProvisionedApp | Remove-ProvisionedAppxPackage -Online -AllUsers
                Write-Output $NewLine
            }
        }

        # Remove AppX Package Apps
        If ($null -ne $AppXPackageApps){
            Write-Output "[ $OEMApplication AppX Packages Installed ]"
            ForEach ($AppXPackageApp in $AppXPackageApps){
                $AppXName = $AppXPackageApp.Name
                Write-Output "$AppXName [AppX Package]"
                $AppXPackageApp | Remove-AppxPackage -AllUsers
                Write-Output $NewLine
            }
        }

        # Remove W32 apps
        If ($null -ne $W32Apps){
            Write-Output "[ $OEMApplication W32 Applications Installed ]"
            ForEach ($W32App in $W32Apps){
                $AppName = $W32App.Name
                Write-Output "$AppName [W32 App]"
                Uninstall-Package -Name $AppName -Force
                Write-Output $NewLine
            }
        }

        # Stop Dell Optimizer Running Process
        $ProcessToStop = "DellOptimizer"
        $OEMProcesses = Get-Process -ProcessName $ProcessToStop -ErrorAction SilentlyContinue

        If ($null -ne $OEMProcesses){
            Write-Output "[ Stop Dell Running Processes ]"
            While ($null -ne $OEMProcesses){
                ForEach ($OEMProcess in $OEMProcesses){
                    $OEMProcessName = $OEMProcess.ProcessName
                    Write-Output "$OEMProcessName Process is Running."
                    Stop-Process -Name $OEMProcessName -Force
                    Start-Sleep -s 5
                    $OEMProcesses = Get-Process -ProcessName $ProcessToStop -ErrorAction SilentlyContinue
                }
            }
            Write-Output "$OEMProcessName Process has been Stopped."
            Write-Output $NewLine
        }

        # Stop and Disable Dell Optimizer Running Services
        $ServiceToStop = "Dell Optimizer"
        $OEMServices = Get-WmiObject win32_service |
        Select-Object Name,DisplayName,State,StartMode |
        Where-Object { $_.DisplayName -like $ServiceToStop } |
        Where-Object {$_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"} -ErrorAction SilentlyContinue

        If ($null -ne $OEMServices){
            Write-Output "[ Stop and Disable Dell Running Services ]"
            While ($null -ne $OEMServices){
                ForEach ($OEMService in $OEMServices){
                    $OEMServiceName = $OEMService.Name
                    $OEMServiceDisplayName = $OEMService.DisplayName
                    $OEMServiceState = $OEMService.State
                    Write-Output "$OEMServiceDisplayName Service is $OEMServiceState."
                    Set-Service -Name $OEMServiceName -StartupType Disabled
                    Stop-Service -Name $OEMServiceName -Force
                    Start-Sleep -s 5
                    $OEMServices = Get-WmiObject win32_service |
                    Select-Object Name,DisplayName,State,StartMode |
                    Where-Object { $_.DisplayName -like $ServiceToStop } |
                    Where-Object {$_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"} -ErrorAction SilentlyContinue
                }
            }
            Write-Output "$OEMServiceDisplayName Service has been Stopped and Disabled."
            Write-Output $NewLine
        }

        # Remove Registry Apps
        If ($null -ne $RegistryApps){
            Write-Output "[ $OEMApplication Registry Applications Installed ]"
            ForEach ($RegistryApp in $RegistryApps){
                $AppDisplayName = $RegistryApp.DisplayName
                $AppGUID = $RegistryApp.PSChildName
                Write-Output "Display Name: $AppDisplayName"

                If ($null -ne $RegistryApp.QuietUninstallString){
                    & $RegistryApp.QuietUninstallString
                } ElseIf ($null -ne $RegistryApp.UninstallString){
                    & $RegistryApp.UninstallString
                } Else {
                    Write-Output "Uninstall string not found for $AppDisplayName."
                }
                Write-Output $NewLine
            }
        }
    }
}

# Verify All Dell OEM Applications are Uninstalled
$OEMApplications = "*Dell*"
ForEach ($OEMApplication in $OEMApplications){
    $RegistryApps = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Select-Object DisplayName, DisplayVersion, QuietUninstallString, UninstallString, PSChildName |
    Where-Object {$_.DisplayName -Like $OEMApplication -And $_.DisplayName -NotMatch $OEMApplicationsToKeep}

    $AppXProvisionedApps = Get-AppxProvisionedPackage -Online |
    Where-Object {$_.DisplayName -Like $OEMApplication -And $_.DisplayName -NotMatch $OEMApplicationsToKeep}

    $AppXPackageApps = Get-AppxPackage -AllUsers |
    Where-Object {$_.Name -Like $OEMApplication -And $_.Name -NotMatch $OEMApplicationsToKeep}

    $W32Apps = Get-Package |
    Where-Object {$_.Name -Like $OEMApplication -And $_.Name -NotMatch $OEMApplicationsToKeep}

    Write-Output "[ Verifying All $OEMApplication OEM Applications are Uninstalled. ]"

    If (($null -eq $RegistryApps) -and ($null -eq $AppXProvisionedApps) -and ($null -eq $AppXPackageApps) -and ($null -eq $W32Apps)){
        Write-Output "All $OEMApplication OEM Applications have been Successfully Uninstalled."
        Write-Output $NewLine

        Write-Output "[ Create Successful Registry Key for Detection Method. ]"
    } Else {
        Write-Output "$OEMApplication OEM Applications that Failed to Uninstall:"

        ForEach ($RegistryApp in $RegistryApps){
            Write-Output $RegistryApp.DisplayName
        }

        ForEach ($AppXProvisionedApp in $AppXProvisionedApps){
            $AppXDisplayName = $AppXProvisionedApp.DisplayName
            Write-Output "$AppXDisplayName [AppX Provisioned App]"
        }

        ForEach ($AppXPackageApp in $AppXPackageApps){
            $AppXName = $AppXPackageApp.Name
            Write-Output "$AppXName [AppX Package]"
        }

        ForEach ($W32App in $W32Apps){
            $AppName = $W32App.Name
            Write-Output "$AppName [W32 App]"
        }
    }
}

# Stop the Logging
Stop-Transcript
