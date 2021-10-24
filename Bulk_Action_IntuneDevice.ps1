# This script can send device actions to a group of devices
# This requires MS Graph API support
# Use "Invoke-DeviceManagement_ManagedDevices_SyncDevice"
# Use "Invoke-DeviceManagement_ManagedDevices_RebootNow"
# Use "Invoke-DeviceManagement_ManagedDevices_ShutDown"
# Please see https://docs.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice?view=graph-rest-1.0 for more details
# Below is the content of the script

Connect-MSGraph
$DeviceGroup = Read-Host -Prompt "Please provide the AAD group object ID"

$DeviceList = Get-Groups_Members -groupId $DeviceGroup -Select id, deviceId, displayName | get-MSGraphAllpages

$AllIntuneDevices = Get-IntuneManagedDevice -select id, operatingSystem, azureADDeviceId -Filter "contains(operatingSystem, 'iOS')" | get-MSGraphAllpages

foreach ($Device in $DeviceList)

{
    $deviceIntuneId = $AllIntuneDevices | Where-Object {$_.azureADDeviceId -eq $Device.deviceId}

    Write-Host $Device.deviceId

    if($deviceIntuneId)
    {
        Invoke-DeviceManagement_ManagedDevices_SyncDevice -managementDeviceId $deviceIntuneID.id

        Write-Host "Sync command has been sent to the device"
    }

    else {
        Write-Host "$Device.deviceId not found"
    }

}