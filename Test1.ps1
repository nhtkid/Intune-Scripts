# This script assigns iOS enrollment profiles to a list of iPads
# Provide a CSV of serial numbers with column heading 'serialnumber'

# Import required module
Import-Module Microsoft.Graph.Intune

# Your App ID (Client ID) goes here
$AppId = "your-app-id-goes-here"  # Replace with your actual App ID

# Function to connect to Microsoft Graph
Function Connect-ToGraph {
    Update-MSGraphEnvironment -AppId $AppId -Quiet
    Connect-MSGraph
}

# Function to get DEP Onboarding Settings
Function Get-DEPOnboardingSettings {
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    
    (Invoke-MSGraphRequest -HttpMethod GET -Url $uri).value
}

# Function to get DEP Profiles
Function Get-DEPProfiles {
    param ($TokenId)
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings/$TokenId/enrollmentProfiles"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    
    (Invoke-MSGraphRequest -HttpMethod GET -Url $uri).value
}

# Updated Function to assign profile to device
Function Assign-ProfileToDevice {
    param (
        [Parameter(Mandatory=$true)]
        $TokenId,
        [Parameter(Mandatory=$true)]
        $ProfileId,
        [Parameter(Mandatory=$true)]
        $SerialNumber
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings/$TokenId/enrollmentProfiles('$ProfileId')/updateDeviceProfileAssignment"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    
    try {
        $DevicesArray = $SerialNumber -split ","
        
        $JSON = @{ 
            "deviceIds" = $DevicesArray 
        } | ConvertTo-Json

        Write-Host "Attempting to assign profile to device(s): $SerialNumber"
        Write-Host "URI: $uri"
        Write-Host "Request Body: $JSON"

        $response = Invoke-MSGraphRequest -HttpMethod POST -Url $uri -Content $JSON -ContentType "application/json"
        
        Write-Host "Success: Device(s) assigned!" -ForegroundColor Green
        Write-Host "Response: $($response | ConvertTo-Json -Depth 5)"
    }
    catch {
        Write-Host
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -ForegroundColor Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        Write-Host
    }
}

# Main script execution
Connect-ToGraph
Write-Host "Connected to Microsoft Graph using App ID: $AppId"

# Get DEP Tokens
$tokens = Get-DEPOnboardingSettings
if ($tokens) {
    # Select a token (if multiple, let user choose)
    $selectedToken = $tokens[0]  # Default to first token
    if ($tokens.Count -gt 1) {
        $tokens | ForEach-Object -Begin {$i=1} -Process {Write-Host "$i: $($_.tokenName)"; $i++}
        $selection = Read-Host "Select a token number"
        $selectedToken = $tokens[$selection - 1]
    }
    Write-Host "Using DEP token: $($selectedToken.tokenName)"

    # Get DEP Profiles
    $profiles = Get-DEPProfiles -TokenId $selectedToken.id
    if ($profiles) {
        # Select a profile
        $profiles | ForEach-Object -Begin {$i=1} -Process {Write-Host "$i: $($_.displayName)"; $i++}
        $selection = Read-Host "Select a profile number"
        $selectedProfile = $profiles[$selection - 1]
        Write-Host "Using profile: $($selectedProfile.displayName)"

        # Get CSV file path and read devices
        $csvPath = Read-Host "Enter the path to your CSV file"
        $devices = Import-Csv $csvPath

        # Process each device
        foreach ($device in $devices) {
            Assign-ProfileToDevice -TokenId $selectedToken.id -ProfileId $selectedProfile.id -SerialNumber $device.serialnumber
        }
    } else {
        Write-Host "No DEP profiles found for the selected token."
    }
} else {
    Write-Host "No DEP tokens found in your environment."
}

Write-Host "Script execution completed."
