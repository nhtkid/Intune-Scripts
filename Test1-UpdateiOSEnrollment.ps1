# Simplified script to assign iOS devices to enrollment profiles in Intune
# Requires Microsoft.Graph.Intune module

# Import required module
Import-Module Microsoft.Graph.Intune

# Authenticate to Microsoft Graph
Connect-MSGraph

# Function to get DEP token ID
function Get-DEPTokenId {
    $depTokens = Get-IntuneManagedDevice -Filter "managementAgent eq 'dep'"
    if ($depTokens.Count -eq 0) {
        Write-Error "No DEP tokens found."
        exit
    }
    if ($depTokens.Count -eq 1) {
        return $depTokens[0].Id
    }
    $depTokens | Format-Table -Property Id, Name
    $tokenId = Read-Host "Enter the ID of the DEP token to use"
    return $tokenId
}

# Function to get enrollment profile ID
function Get-EnrollmentProfileId {
    $profiles = Get-IntuneManagedDeviceEnrollmentProfile
    if ($profiles.Count -eq 0) {
        Write-Error "No enrollment profiles found."
        exit
    }
    $profiles | Format-Table -Property Id, DisplayName
    $profileId = Read-Host "Enter the ID of the enrollment profile to assign"
    return $profileId
}

# Main script
$tokenId = Get-DEPTokenId
$profileId = Get-EnrollmentProfileId

$csvPath = Read-Host "Enter the path to the CSV file containing device serial numbers"
$devices = Import-Csv $csvPath

foreach ($device in $devices) {
    $serialNumber = $device.SerialNumber
    try {
        $depDevice = Get-IntuneManagedDevice -Filter "serialNumber eq '$serialNumber'"
        if ($null -eq $depDevice) {
            Write-Warning "Device with serial number $serialNumber not found in DEP."
            continue
        }
        
        $uri = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings/$tokenId/enrollmentProfiles('$profileId')/updateDeviceProfileAssignment"
        $body = @{
            "deviceIds" = @($serialNumber)
        } | ConvertTo-Json

        Invoke-MSGraphRequest -HttpMethod POST -Url $uri -Content $body

        Write-Host "Successfully assigned profile to device $serialNumber" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to assign profile to device $serialNumber. Error: $_"
    }
}

Write-Host "Profile assignment process completed."
