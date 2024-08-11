<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

####################################################

function Get-AuthToken {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host

    Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }

    if($AadModule.count -gt 1){
        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

        if($AadModule.count -gt 1){
            $aadModule = $AadModule | select -Unique
        }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }
    else {
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $clientId = "<your-client-id>"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    try {
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

        if($authResult.AccessToken){
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $authResult.AccessToken
                'ExpiresOn'=$authResult.ExpiresOn
            }
            return $authHeader
        }
        else {
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
        }
    }
    catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        Write-Host "Error occurred while acquiring token. Please check your credentials and permissions." -ForegroundColor Red
        Write-Host "Exception details: $($_.Exception)" -ForegroundColor Red
        Write-Host
        break
    }
}

####################################################

Function Test-JSON(){
    param (
        $JSON
    )

    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $validJson = $true
    }
    catch {
        $validJson = $false
        $_.Exception
    }

    if (!$validJson){
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }
}

####################################################

Function Get-DEPOnboardingSettings {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory=$false)]
        [string]$tokenid
    )
    
    $graphApiVersion = "beta"
    
    try {
        if ($tokenid){
            $Resource = "deviceManagement/depOnboardingSettings/$tokenid/"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get)
        }
        else {
            $Resource = "deviceManagement/depOnboardingSettings/"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).value
        }
    }
    catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    }
} 

####################################################

Function Get-DEPProfiles(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $id
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings/$id/enrollmentProfiles"

    try {
        $SyncURI = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
        Invoke-RestMethod -Uri $SyncURI -Headers $authToken -Method GET
    }
    catch {
        Write-Host
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    }
}

####################################################

Function Assign-ProfileToDevice(){
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $DepOnboardingSettingId,
        [Parameter(Mandatory=$true)]
        $EnrollmentProfileId,
        [Parameter(Mandatory=$true)]
        $SerialNumber
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/depOnboardingSettings/$DepOnboardingSettingId/enrollmentProfiles/$EnrollmentProfileId/updateDeviceProfileAssignment"

    try {
        $DevicesArray = @($SerialNumber)
        
        $JSON = @{
            "deviceIds" = $DevicesArray
        } | ConvertTo-Json

        Write-Host "Attempting to assign profile to device(s): $SerialNumber"
        Write-Host "URI: $uri"
        Write-Host "Request Body: $JSON"

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        $response = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"
        
        Write-Host "Success: Device(s) assigned!" -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host "Status Code: $statusCode" -ForegroundColor Red
            
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response content:`n$responseBody" -ForegroundColor Red
        }
        Write-Host "Request to $Uri failed." -ForegroundColor Red
    }
}

####################################################

#region Authentication

write-host

# Checking if authToken exists before running authentication
if($global:authToken){
    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if($TokenExpires -le 0){
        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

        # Defining User Principal Name if not present
        if($User -eq $null -or $User -eq ""){
            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
            Write-Host
        }

        $global:authToken = Get-AuthToken -User $User
    }
}

# Authentication doesn't exist, calling Get-AuthToken function
else {
    if($User -eq $null -or $User -eq ""){
        $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
        Write-Host
    }

    # Getting the authorization token
    $global:authToken = Get-AuthToken -User $User
}

#endregion

####################################################

#region DEP Tokens

$tokens = (Get-DEPOnboardingSettings)

if($tokens){
    $tokencount = @($tokens).count

    Write-Host "DEP tokens found: $tokencount"
    Write-Host

    if ($tokencount -gt 1){
        write-host "Listing DEP tokens..." -ForegroundColor Yellow
        Write-Host
        $DEP_Tokens = $tokens.tokenName | Sort-Object -Unique

        $menu = @{}

        for ($i=1; $i -le $DEP_Tokens.count; $i++) 
        { 
            Write-Host "$i. $($DEP_Tokens[$i-1])" 
            $menu.Add($i,($DEP_Tokens[$i-1]))
        }

        Write-Host
        [int]$ans = Read-Host 'Select the token you wish to use (numerical value)'
        $selection = $menu.Item($ans)
        Write-Host

        if ($selection){
            $SelectedToken = $tokens | Where-Object { $_.TokenName -eq "$Selection" }
            $SelectedTokenId = $SelectedToken | Select-Object -ExpandProperty id
            $id = $SelectedTokenId
        }
    }
    elseif ($tokencount -eq 1) {
        $id = (Get-DEPOnboardingSettings).id
    }
}
else {
    Write-Warning "No DEP tokens found!"
    Write-Host
    break
}

#endregion 

####################################################

$DeviceSerialNumber = Read-Host "Please enter device serial number"

# If variable contains spaces, remove them
$DeviceSerialNumber = $DeviceSerialNumber.replace(" ","")

if(!($DeviceSerialNumber)){
    Write-Host "Error: No serial number entered!" -ForegroundColor Red
    Write-Host
    break
}

$graphApiVersion = "beta"
$Resource = "deviceManagement/depOnboardingSettings/$($id)/importedAppleDeviceIdentities?`$filter=discoverySource eq 'deviceEnrollmentProgram' and contains(serialNumber,'$DeviceSerialNumber')"

$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
$SearchResult = (Invoke-RestMethod -Uri $uri –Headers $authToken –Method Get).value

if (!($SearchResult)){
    Write-warning "Can't find device $DeviceSerialNumber."
    Write-Host
    break
}

####################################################

$Profiles = (Get-DEPProfiles -id $id).value

if($Profiles){
    Write-Host
    Write-Host "Listing DEP Profiles..." -ForegroundColor Yellow
    Write-Host

    $enrollmentProfiles = $Profiles.displayname | Sort-Object -Unique

    $menu = @{}

    for ($i=1; $i -le $enrollmentProfiles.count; $i++) 
    { 
        Write-Host "$i. $($enrollmentProfiles[$i-1])" 
        $menu.Add($i,($enrollmentProfiles[$i-1]))
    }

    Write-Host
    $ans = Read-Host 'Select the profile you wish to assign (numerical value)'

    # Checking if read-host of DEP Profile is an integer
    if(($ans -match "^[\d\.]+$") -eq $true){
        $selection = $menu.Item([int]$ans)
    }

    if ($selection){
        $SelectedProfile = $Profiles | Where-Object { $_.DisplayName -eq "$Selection" }
        $SelectedProfileId = $SelectedProfile | Select-Object -ExpandProperty id
        $ProfileID = $SelectedProfileId
    }
    else {
        Write-Host
        Write-Warning "DEP Profile selection invalid. Exiting..."
        Write-Host
        break
    }
}
else {
    Write-Host
    Write-Warning "No DEP profiles found!"
    break
}

####################################################

Assign-ProfileToDevice -DepOnboardingSettingId $id -EnrollmentProfileId $ProfileID -SerialNumber $DeviceSerialNumber

Write-Host "Script execution completed."
