
function Read-HostYesNo ([string]$Title, [string]$Prompt, [boolean]$Default)
{
    # Set up native PowerShell choice prompt with Yes and No
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    
    # Set default option
    $defaultChoice = 0 # first choice = Yes
    if ($Default -eq $false) { # only if it was given and is false
        $defaultChoice = 1 # second choice = No
    }

    $result = $Host.UI.PromptForChoice($Title, $Prompt, $options, $defaultChoice)
    
    if ($result -eq 0) { # 0 is yes
        return $true
    } else {
        return $false
    }
}
####################################################

function ConnectToGraph
{
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) 
    {
    } 
    else {
        Write-Host "Microsoft.Graph.Intune Module does not exist, installing..."
        Install-Module -Name Microsoft.Graph.Intune
    }
    <#
    $yourUPN = "xxx@kunintune.onmicrosoft.com"
    $password = ConvertTo-SecureString 'xxxxx' -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($yourUPN, $password)
    #>

    #Connect-MSGraph -PSCredential $creds
    
    connect-MSGraph
}

########################################################

function Get-AllAutopilotdevices()
{
    $URL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
    $result = invoke-MSGraphRequest -HttpMethod GET -Url $URL | Get-MSGraphAllPages
    return $result



  
}

#######################################################


function update-AutopilotgroupTab($autopilotDeviceID, $GroupTag)
{
    $URL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$autopilotDeviceID/UpdateDeviceProperties"
    Write-host  $URL 

      try { 
               
       Invoke-MSGraphRequest -Url $URL -Content "{groupTag: '$GroupTag'}" -HttpMethod POST -Verbose
    }
      catch {
    
        Write-Host($_)
        Write-host  $URL 
            Continue
    
        }
    
}

#######################################################


ConnectToGraph
#read CSv
# When entering a CSV path, "" is unnecessary even if there is a space in the file path.
$CSVPath = Read-Host("CSV Enter the file path")
$CSVDevices = Import-Csv -Path $CSVPath -Header "Serialnumber"

Write-host $CSVDevices


#all Autopilot devices
$Autopilotdevice = Get-AllAUtopilotdevices | select id, groupTag, serialNumber

$Autopilotdevice | format-table

$GroupTag = Read-Host("Put Group tag need to be added")
write-host

$displayTable = Read-HostYesNo -Prompt "Do you want to change group tag to $GroupTag ?" -Default $true





if($displayTable){
  

    if($CSVDevices){
        foreach($Device in $CSVDevices)
        {

            if ($Device -eq "Serial number")
            {
                Continue
            }
            else
            {
                $DeviceGroupTagNeedChange = $Autopilotdevice | Where-Object {$_.Serialnumber -eq $Device.Serialnumber} 
                if ($DeviceGroupTagNeedChange)
                {
                    write-host $DeviceGroupTagNeedChange.id
       
                   
                    update-AutopilotgroupTab -autopilotDeviceID $DeviceGroupTagNeedChange.id -GroupTag $GroupTag
                   
                    $deviceseralnumber = $Device.Serialnumber
                   
                    Write-host "Device with Serial number $deviceseralnumber has been changed its GroupTag with $GroupTag"
                    write-host
                }
            }
          
        }

    }

    Write-Host
}

