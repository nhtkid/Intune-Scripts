# Define Log Path
$ScriptVersion = "1.3"
$DateTime = [DateTime]::Now.ToString("yyyyMMdd")
$LogFile = "NAB-UninstallDellOEMApplications-" + $ScriptVersion + "_" + $DateTime + ".log"
$LogPath = "C:\Windows\CCM\Logs"
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
    "Dell SupportAssist OS Recovery",
    "Dell SupportAssist OS Recovery Plugin for Dell Update",
    "Dell Command | Update for Windows Universal",
    "DellInc.DellCommandUpdate",
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

    # Check if any applications were found
    If (($null -eq $RegistryApps) -and ($null -eq $AppXProvisionedApps) -and ($null -eq $AppXPackageApps)){
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
        $OEMServices = GWMI win32_service | 
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
                    $OEMServices = GWMI win32_service | 
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
                    $AppUninstallString = $RegistryApp.QuietUninstallString
                } Else {
                    $AppUninstallString = $RegistryApp.UninstallString
                }

                If ($AppUninstallString -match "msiexec.exe"){
                    $AppUninstallString = $AppUninstallString -replace 'msiexec.exe /i','msiexec.exe /x '
                    # Uninstall OEMApplication via MSI Uninstall String
                    $ArgumentList = "/Uninstall $AppGUID /qn /norestart"
                    Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList "$ArgumentList" -Wait -Verbose -WindowStyle Hidden -ErrorAction SilentlyContinue
                    Write-Output "MSI GUID: $AppGUID"
                    Write-Output "MSI Uninstall String: $AppUninstallString"
                    Start-Sleep -s 10
                } Else {
                    $AppUninstallStringSplit = $AppUninstallString -split ".exe"
                    $AppUninstallProcess = $AppUninstallStringSplit[0] -replace ('"','')
                    $AppUninstallProcess = "$AppUninstallProcess.exe"
                    $AppUninstallArgumentList = $AppUninstallStringSplit[1] -replace ('"','')

                    Write-Output "App Uninstall String: $AppUninstallString"
                    Write-Output "App Uninstall Process: $AppUninstallProcess"

                    If (($AppUninstallArgumentList -like "*silent*") -or ($AppUninstallArgumentList -like "*quiet*")){
                        # Uninstall OEMApplication via Uninstall String
                        Write-Output "App Uninstall Argument List: $AppUninstallArgumentList"
                        Start-Process "$AppUninstallProcess" -ArgumentList "$AppUninstallArgumentList" -Wait -Verbose -WindowStyle Hidden -ErrorAction SilentlyContinue
                        Start-Sleep -s 10
                    } Else {
                        # Uninstall OEMApplication via Uninstall String with Silent Switch
                        $AppUninstallArgumentList = "$AppUninstallArgumentList -silent"
                        Write-Output "App Uninstall Argument List: $AppUninstallArgumentList"
                        Start-Process "$AppUninstallProcess" -ArgumentList "$AppUninstallArgumentList" -Wait -Verbose -WindowStyle Hidden -ErrorAction SilentlyContinue
                        Start-Sleep -s 10
                    }
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

    Write-Output "[ Verifying All $OEMApplication OEM Applications are Uninstalled. ]"

    If (($null -eq $RegistryApps) -and ($null -eq $AppXProvisionedApps) -and ($null -eq $AppXPackageApps)){
        Write-Output "All $OEMApplication OEM Applications have been Successfully Uninstalled."
        Write-Output $NewLine

        Write-Output "[ Create Successful Registry Key for Detection Method. ]"
        # Create Registry Key for Detection Method
        If ($ENV:COMPUTERNAME -match "MNAB"){
            $NABDevice = "AAD"
        } Else {
            $NABDevice = "SOE"
        }

        New-Item -Path "HKLM:\Software\NAB" -ErrorAction Ignore | Out-Null
        New-Item -Path "HKLM:\Software\NAB\$NABDevice" -ErrorAction Ignore | Out-Null
        New-ItemProperty -Path "HKLM:\Software\NAB\$NABDevice" -Name "Uninstall Dell OEM Applications" -Value $ScriptVersion -Force | Out-Null
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
    }
}

# Stop the Logging
Stop-Transcript
