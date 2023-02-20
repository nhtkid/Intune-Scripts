# Prompt the user to sign in to Microsoft Graph
Connect-MSGraph

# Retrieve the device configuration profiles and app protection policies
$deviceProfiles = Get-IntuneDeviceConfiguration
$appProtectionPolicies = Get-IntuneAppProtectionPolicy

# Define an object to store the profile/policy details
$profilesAndPolicies = @()

# Add the device configuration profiles to the object
foreach ($profile in $deviceProfiles) {
    $profileType = $profile.ODataType.Substring($profile.ODataType.LastIndexOf('.') + 1)
    $platform = $profile.PlatformType
    $profileDetails = [PSCustomObject] @{
        Name = $profile.DisplayName
        ID = $profile.Id
        Type = $profileType
        Platform = $platform
    }
    $profilesAndPolicies += $profileDetails
}

# Add the app protection policies to the object
foreach ($policy in $appProtectionPolicies) {
    $policyType = $policy.ODataType.Substring($policy.ODataType.LastIndexOf('.') + 1)
    $platform = $policy.Platform
    $policyDetails = [PSCustomObject] @{
        Name = $policy.DisplayName
        ID = $policy.Id
        Type = $policyType
        Platform = $platform
    }
    $profilesAndPolicies += $policyDetails
}

# Group the profiles/policies by platform and type, and display the results
$profilesAndPolicies | Group-Object Platform,Type | Sort-Object Name | ForEach-Object {
    $platform = $_.Name[0]
    $type = $_.Name[1]
    Write-Host "$platform $type profiles/policies:"
    $_.Group | Sort-Object Name | ForEach-Object {
        Write-Host "- $($_.Name) ($($_.ID))"
    }
    Write-Host ""
}
