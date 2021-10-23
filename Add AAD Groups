# This script can bulk add or remove objects to AAD group.
# It works for both user or device group
# Make sure you prepare a csv list with Azure user or device's Object ID
# Column headings used in csv include: ObjectID and DeviceName
# Below is the content of the script

$devicelist = Import-Csv 'path to your file.csv'
# to add members
foreach ($device in $devicelist) {
    try {
        add-AzureADGroupMember -ObjectID typeyourgroupid -RefObjectId $device.ObjectID
        Write-Host "Device has been added:$($device.DeviceName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Device not found:$($device.DeviceName)" -ForegroundColor Red
    }
    
}
# to remove members
foreach ($device in $devicelist) {
    try {
        remove-AzureADGroupMember -ObjectID typeyourgroupid -MemberId $device.ObjectID
        Write-Host "Device has been removed:$($device.DeviceName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Device not found:$($device.DeviceName)" -ForegroundColor Red
    }
    
}
