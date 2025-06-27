<#
.SYNOPSIS
    Azure AD Group Management Tool - Interactive PowerShell script for managing Azure Active Directory group memberships

.DESCRIPTION
    This script provides an interactive menu-driven interface for managing Azure AD group members.
    After connecting to Azure AD and selecting a target group, choose from three main functions:

    1. Show Members - View group members by typing * to show all members or enter a name to search 
       for users with matching first name, last name, or display name.

    2. Add Members - Add users to the group by pasting space-separated email addresses/UPNs into 
       the console, or provide a local CSV file path with 'EmailAddress' column heading.

    3. Remove Members - Remove users from the group by pasting space-separated email addresses/UPNs 
       into the console, or provide a local CSV file path with 'EmailAddress' column heading.

.PARAMETER None
    This script runs interactively and prompts for all required parameters

.EXAMPLE
    PS> .\AAD-GroupManager.ps1
    Launches the interactive group management tool

.NOTES
    Requirements: 
    - PowerShell 5.1 or higher
    - AzureAD PowerShell module
    - Azure AD administrative permissions for target groups

    CSV File Format:
    EmailAddress
    user1@domain.com
    user2@domain.com

.LINK
    https://docs.microsoft.com/en-us/powershell/module/azuread/
#>

# Requires AzureAD PowerShell module
# Compatible with PowerShell 5.1 ISE

# Check if AzureAD module is available
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Write-Host "AzureAD PowerShell module is not installed. Please install it using:" -ForegroundColor Red
    Write-Host "Install-Module -Name AzureAD -Force" -ForegroundColor Yellow
    exit
}

# Import AzureAD module
Import-Module AzureAD -Force

# Connect to Azure AD
try {
    Write-Host "Connecting to Azure AD..." -ForegroundColor Yellow
    Connect-AzureAD | Out-Null
    Write-Host "Successfully connected to Azure AD" -ForegroundColor Green
}
catch {
    Write-Host "Failed to connect to Azure AD: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Function to get group by name
function Get-AADGroupByName {
    param([string]$GroupName)
    
    try {
        # Try exact match first
        $group = Get-AzureADGroup -All $true | Where-Object { $_.DisplayName -eq $GroupName }
        if (-not $group) {
            $group = Get-AzureADGroup -All $true | Where-Object { $_.MailNickname -eq $GroupName }
        }
        # If still not found, try partial match
        if (-not $group) {
            $group = Get-AzureADGroup -All $true | Where-Object { $_.DisplayName -like "*$GroupName*" }
        }
        return $group
    }
    catch {
        Write-Host "Error finding group: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to find user by email or UPN
function Find-AADUser {
    param([string]$EmailOrUPN)
    
    try {
        # Try multiple methods to find the user
        $user = $null
        
        # Method 1: Direct ObjectId lookup if it looks like a GUID
        if ($EmailOrUPN -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}
function Show-GroupMembers {
    param(
        [string]$GroupObjectId,
        [string]$SearchQuery = "*"
    )
    
    try {
        Write-Host "Retrieving group members..." -ForegroundColor Yellow
        $members = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
        
        if ($members.Count -eq 0) {
            Write-Host "No members found in the group." -ForegroundColor Yellow
            return
        }
        
        # Filter members based on search query
        $filteredMembers = @()
        
        foreach ($member in $members) {
            if ($member.ObjectType -eq "User") {
                $user = Get-AzureADUser -ObjectId $member.ObjectId
                
                if ($SearchQuery -eq "*" -or 
                    $user.DisplayName -like "*$SearchQuery*" -or
                    $user.GivenName -like "*$SearchQuery*" -or
                    $user.Surname -like "*$SearchQuery*") {
                    $filteredMembers += $user
                }
            }
        }
        
        # Display header
        Write-Host ""
        Write-Host ("{0,-30} {1,-15} {2,-35} {3,-20}" -f "DisplayName", "EmployeeID", "Mail", "Department") -ForegroundColor Cyan
        Write-Host ("-" * 100) -ForegroundColor Cyan
        
        # Display members one by one (streamed)
        $count = 0
        foreach ($user in $filteredMembers) {
            $displayName = if ($user.DisplayName) { $user.DisplayName } else { "N/A" }
            $employeeId = if ($user.ExtensionProperty.employeeId) { $user.ExtensionProperty.employeeId } else { "N/A" }
            $mail = if ($user.Mail) { $user.Mail } else { $user.UserPrincipalName }
            $department = if ($user.Department) { $user.Department } else { "N/A" }
            
            Write-Host ("{0,-30} {1,-15} {2,-35} {3,-20}" -f 
                $displayName.Substring(0, [Math]::Min(29, $displayName.Length)),
                $employeeId.Substring(0, [Math]::Min(14, $employeeId.Length)),
                $mail.Substring(0, [Math]::Min(34, $mail.Length)),
                $department.Substring(0, [Math]::Min(19, $department.Length))
            ) -ForegroundColor White
            
            $count++
            Start-Sleep -Milliseconds 100  # Small delay for streaming effect
        }
        
        Write-Host ""
        Write-Host "$count members found" -ForegroundColor Green
    }
    catch {
        Write-Host "Error retrieving members: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to add members to group
function Add-GroupMembers {
    param(
        [string]$GroupObjectId,
        [array]$EmailAddresses
    )
    
    $addedCount = 0
    $failedMembers = @()
    
    Write-Host "Adding members to group..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($email in $EmailAddresses) {
        $email = $email.Trim()
        if ([string]::IsNullOrWhiteSpace($email)) { continue }
        
        try {
            # Find user using improved search function
            $user = Find-AADUser -EmailOrUPN $email
            
            if ($user) {
                # Check if user is already a member
                $existingMember = Get-AzureADGroupMember -ObjectId $GroupObjectId | Where-Object { $_.ObjectId -eq $user.ObjectId }
                
                if ($existingMember) {
                    Write-Host "Already member - $email" -ForegroundColor Yellow
                }
                else {
                    Add-AzureADGroupMember -ObjectId $GroupObjectId -RefObjectId $user.ObjectId
                    Write-Host "Added - $email" -ForegroundColor Green
                    $addedCount++
                }
            }
            else {
                Write-Host "Failed - $email (User not found)" -ForegroundColor Red
                $failedMembers += "$email (User not found)"
            }
        }
        catch {
            Write-Host "Failed - $email ($($_.Exception.Message))" -ForegroundColor Red
            $failedMembers += "$email ($($_.Exception.Message))"
        }
        
        Start-Sleep -Milliseconds 200  # Small delay for streaming effect
    }
    
    # Summary
    Write-Host ""
    Write-Host "$addedCount members added" -ForegroundColor Green
    
    if ($failedMembers.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed to add the following members:" -ForegroundColor Red
        foreach ($failed in $failedMembers) {
            Write-Host "  - $failed" -ForegroundColor Red
        }
    }
}

# Function to remove members from group
function Remove-GroupMembers {
    param(
        [string]$GroupObjectId,
        [array]$EmailAddresses
    )
    
    $removedCount = 0
    $failedMembers = @()
    
    Write-Host "Removing members from group..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($email in $EmailAddresses) {
        $email = $email.Trim()
        if ([string]::IsNullOrWhiteSpace($email)) { continue }
        
        try {
            # Find user using improved search function
            $user = Find-AADUser -EmailOrUPN $email
            
            if ($user) {
                # Check if user is a member
                $existingMember = Get-AzureADGroupMember -ObjectId $GroupObjectId | Where-Object { $_.ObjectId -eq $user.ObjectId }
                
                if ($existingMember) {
                    Remove-AzureADGroupMember -ObjectId $GroupObjectId -MemberId $user.ObjectId
                    Write-Host "Removed - $email" -ForegroundColor Green
                    $removedCount++
                }
                else {
                    Write-Host "Failed - $email (Not a member)" -ForegroundColor Yellow
                    $failedMembers += "$email (Not a member)"
                }
            }
            else {
                Write-Host "Failed - $email (User not found)" -ForegroundColor Red
                $failedMembers += "$email (User not found)"
            }
        }
        catch {
            Write-Host "Failed - $email ($($_.Exception.Message))" -ForegroundColor Red
            $failedMembers += "$email ($($_.Exception.Message))"
        }
        
        Start-Sleep -Milliseconds 200  # Small delay for streaming effect
    }
    
    # Summary
    Write-Host ""
    Write-Host "$removedCount members removed" -ForegroundColor Green
    
    if ($failedMembers.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed to remove the following members:" -ForegroundColor Red
        foreach ($failed in $failedMembers) {
            Write-Host "  - $failed" -ForegroundColor Red
        }
    }
}

# Function to get email addresses from user input
function Get-EmailAddressesFromInput {
    Write-Host ""
    Write-Host "Enter email addresses/UPNs separated by spaces, or provide path to CSV file:" -ForegroundColor Cyan
    Write-Host "(For CSV file: enter full path like C:\temp\users.csv)" -ForegroundColor Gray
    $input = Read-Host "Input"
    
    if ($input -like "*.csv") {
        # Handle CSV file
        if (Test-Path $input) {
            try {
                $csvData = Import-Csv -Path $input
                $columnNames = $csvData[0].PSObject.Properties.Name
                
                if ($columnNames -contains "EmailAddress") {
                    Write-Host "Using EmailAddress column from CSV" -ForegroundColor Green
                    return $csvData.EmailAddress | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                }
                elseif ($columnNames -contains "Email") {
                    Write-Host "Using Email column from CSV" -ForegroundColor Green  
                    return $csvData.Email | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                }
                elseif ($columnNames -contains "Mail") {
                    Write-Host "Using Mail column from CSV" -ForegroundColor Green
                    return $csvData.Mail | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                }
                elseif ($columnNames -contains "UserPrincipalName") {
                    Write-Host "Using UserPrincipalName column from CSV" -ForegroundColor Green
                    return $csvData.UserPrincipalName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                }
                else {
                    Write-Host "Available columns in CSV: $($columnNames -join ', ')" -ForegroundColor Yellow
                    Write-Host "CSV file must contain one of these columns: EmailAddress, Email, Mail, or UserPrincipalName" -ForegroundColor Red
                    return @()
                }
            }
            catch {
                Write-Host "Error reading CSV file: $($_.Exception.Message)" -ForegroundColor Red
                return @()
            }
        }
        else {
            Write-Host "CSV file not found: $input" -ForegroundColor Red
            return @()
        }
    }
    else {
        # Handle space-separated email addresses
        return $input -split '\s+' | Where-Object { $_ -ne "" }
    }
}

# Main script execution
Write-Host "=== Azure AD Group Management Tool ===" -ForegroundColor Cyan
Write-Host ""

# Get group name from user
$groupName = Read-Host "Please provide the group name"

if ([string]::IsNullOrWhiteSpace($groupName)) {
    Write-Host "Group name cannot be empty" -ForegroundColor Red
    exit
}

# Find the group
$group = Get-AADGroupByName -GroupName $groupName

if (-not $group) {
    Write-Host "Group '$groupName' not found" -ForegroundColor Red
    exit
}

Write-Host "Found group: $($group.DisplayName)" -ForegroundColor Green
Write-Host "Group ID: $($group.ObjectId)" -ForegroundColor Gray
Write-Host ""

# Main menu loop
do {
    Write-Host "=== Options ===" -ForegroundColor Cyan
    Write-Host "1. Show members"
    Write-Host "2. Add members"
    Write-Host "3. Remove members"
    Write-Host "4. Exit"
    Write-Host ""
    
    $choice = Read-Host "Select an option (1-4)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "Enter to show all members or type a name to search:" -ForegroundColor Cyan
            $searchQuery = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($searchQuery)) {
                $searchQuery = "*"
            }
            
            Show-GroupMembers -GroupObjectId $group.ObjectId -SearchQuery $searchQuery
        }
        
        "2" {
            $emailAddresses = Get-EmailAddressesFromInput
            if ($emailAddresses.Count -gt 0) {
                Add-GroupMembers -GroupObjectId $group.ObjectId -EmailAddresses $emailAddresses
            }
            else {
                Write-Host "No email addresses provided" -ForegroundColor Yellow
            }
        }
        
        "3" {
            $emailAddresses = Get-EmailAddressesFromInput
            if ($emailAddresses.Count -gt 0) {
                Remove-GroupMembers -GroupObjectId $group.ObjectId -EmailAddresses $emailAddresses
            }
            else {
                Write-Host "No email addresses provided" -ForegroundColor Yellow
            }
        }
        
        "4" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            break
        }
        
        default {
            Write-Host "Invalid option. Please select 1-4." -ForegroundColor Red
        }
    }
    
    if ($choice -ne "4") {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
        Write-Host "=== Azure AD Group Management Tool ===" -ForegroundColor Cyan
        Write-Host "Working with group: $($group.DisplayName)" -ForegroundColor Green
        Write-Host ""
    }
    
} while ($choice -ne "4")

Write-Host "Script completed." -ForegroundColor Green) {
            try {
                $user = Get-AzureADUser -ObjectId $EmailOrUPN
            } catch { }
        }
        
        # Method 2: Try UserPrincipalName lookup
        if (-not $user) {
            try {
                $user = Get-AzureADUser -ObjectId $EmailOrUPN
            } catch { }
        }
        
        # Method 3: Search all users if direct lookup failed
        if (-not $user) {
            $allUsers = Get-AzureADUser -All $true
            $user = $allUsers | Where-Object { 
                $_.UserPrincipalName -eq $EmailOrUPN -or 
                $_.Mail -eq $EmailOrUPN -or
                $_.ProxyAddresses -contains "smtp:$EmailOrUPN" -or
                $_.ProxyAddresses -contains "SMTP:$EmailOrUPN"
            } | Select-Object -First 1
        }
        
        return $user
    }
    catch {
        Write-Host "Error searching for user $EmailOrUPN : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}
function Show-GroupMembers {
    param(
        [string]$GroupObjectId,
        [string]$SearchQuery = "*"
    )
    
    try {
        Write-Host "Retrieving group members..." -ForegroundColor Yellow
        $members = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
        
        if ($members.Count -eq 0) {
            Write-Host "No members found in the group." -ForegroundColor Yellow
            return
        }
        
        # Filter members based on search query
        $filteredMembers = @()
        
        foreach ($member in $members) {
            if ($member.ObjectType -eq "User") {
                $user = Get-AzureADUser -ObjectId $member.ObjectId
                
                if ($SearchQuery -eq "*" -or 
                    $user.DisplayName -like "*$SearchQuery*" -or
                    $user.GivenName -like "*$SearchQuery*" -or
                    $user.Surname -like "*$SearchQuery*") {
                    $filteredMembers += $user
                }
            }
        }
        
        # Display header
        Write-Host ""
        Write-Host ("{0,-30} {1,-15} {2,-35} {3,-20}" -f "DisplayName", "EmployeeID", "Mail", "Department") -ForegroundColor Cyan
        Write-Host ("-" * 100) -ForegroundColor Cyan
        
        # Display members one by one (streamed)
        $count = 0
        foreach ($user in $filteredMembers) {
            $displayName = if ($user.DisplayName) { $user.DisplayName } else { "N/A" }
            $employeeId = if ($user.ExtensionProperty.employeeId) { $user.ExtensionProperty.employeeId } else { "N/A" }
            $mail = if ($user.Mail) { $user.Mail } else { $user.UserPrincipalName }
            $department = if ($user.Department) { $user.Department } else { "N/A" }
            
            Write-Host ("{0,-30} {1,-15} {2,-35} {3,-20}" -f 
                $displayName.Substring(0, [Math]::Min(29, $displayName.Length)),
                $employeeId.Substring(0, [Math]::Min(14, $employeeId.Length)),
                $mail.Substring(0, [Math]::Min(34, $mail.Length)),
                $department.Substring(0, [Math]::Min(19, $department.Length))
            ) -ForegroundColor White
            
            $count++
            Start-Sleep -Milliseconds 100  # Small delay for streaming effect
        }
        
        Write-Host ""
        Write-Host "$count members found" -ForegroundColor Green
    }
    catch {
        Write-Host "Error retrieving members: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to add members to group
function Add-GroupMembers {
    param(
        [string]$GroupObjectId,
        [array]$EmailAddresses
    )
    
    $addedCount = 0
    $failedMembers = @()
    
    Write-Host "Adding members to group..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($email in $EmailAddresses) {
        $email = $email.Trim()
        if ([string]::IsNullOrWhiteSpace($email)) { continue }
        
        try {
            # Find user by email or UPN
            $user = Get-AzureADUser -Filter "Mail eq '$email' or UserPrincipalName eq '$email'"
            
            if ($user) {
                # Check if user is already a member
                $existingMember = Get-AzureADGroupMember -ObjectId $GroupObjectId | Where-Object { $_.ObjectId -eq $user.ObjectId }
                
                if ($existingMember) {
                    Write-Host "Already member - $email" -ForegroundColor Yellow
                }
                else {
                    Add-AzureADGroupMember -ObjectId $GroupObjectId -RefObjectId $user.ObjectId
                    Write-Host "Added - $email" -ForegroundColor Green
                    $addedCount++
                }
            }
            else {
                Write-Host "Failed - $email (User not found)" -ForegroundColor Red
                $failedMembers += "$email (User not found)"
            }
        }
        catch {
            Write-Host "Failed - $email ($($_.Exception.Message))" -ForegroundColor Red
            $failedMembers += "$email ($($_.Exception.Message))"
        }
        
        Start-Sleep -Milliseconds 200  # Small delay for streaming effect
    }
    
    # Summary
    Write-Host ""
    Write-Host "$addedCount members added" -ForegroundColor Green
    
    if ($failedMembers.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed to add the following members:" -ForegroundColor Red
        foreach ($failed in $failedMembers) {
            Write-Host "  - $failed" -ForegroundColor Red
        }
    }
}

# Function to remove members from group
function Remove-GroupMembers {
    param(
        [string]$GroupObjectId,
        [array]$EmailAddresses
    )
    
    $removedCount = 0
    $failedMembers = @()
    
    Write-Host "Removing members from group..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($email in $EmailAddresses) {
        $email = $email.Trim()
        if ([string]::IsNullOrWhiteSpace($email)) { continue }
        
        try {
            # Find user by email or UPN
            $user = Get-AzureADUser -Filter "Mail eq '$email' or UserPrincipalName eq '$email'"
            
            if ($user) {
                # Check if user is a member
                $existingMember = Get-AzureADGroupMember -ObjectId $GroupObjectId | Where-Object { $_.ObjectId -eq $user.ObjectId }
                
                if ($existingMember) {
                    Remove-AzureADGroupMember -ObjectId $GroupObjectId -MemberId $user.ObjectId
                    Write-Host "Removed - $email" -ForegroundColor Green
                    $removedCount++
                }
                else {
                    Write-Host "Failed - $email (Not a member)" -ForegroundColor Yellow
                    $failedMembers += "$email (Not a member)"
                }
            }
            else {
                Write-Host "Failed - $email (User not found)" -ForegroundColor Red
                $failedMembers += "$email (User not found)"
            }
        }
        catch {
            Write-Host "Failed - $email ($($_.Exception.Message))" -ForegroundColor Red
            $failedMembers += "$email ($($_.Exception.Message))"
        }
        
        Start-Sleep -Milliseconds 200  # Small delay for streaming effect
    }
    
    # Summary
    Write-Host ""
    Write-Host "$removedCount members removed" -ForegroundColor Green
    
    if ($failedMembers.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed to remove the following members:" -ForegroundColor Red
        foreach ($failed in $failedMembers) {
            Write-Host "  - $failed" -ForegroundColor Red
        }
    }
}

# Function to get email addresses from user input
function Get-EmailAddressesFromInput {
    Write-Host ""
    Write-Host "Enter email addresses/UPNs separated by spaces, or provide path to CSV file:" -ForegroundColor Cyan
    Write-Host "(For CSV file: enter full path like C:\temp\users.csv)" -ForegroundColor Gray
    $input = Read-Host "Input"
    
    if ($input -like "*.csv") {
        # Handle CSV file
        if (Test-Path $input) {
            try {
                $csvData = Import-Csv -Path $input
                if ($csvData[0].PSObject.Properties.Name -contains "EmailAddress") {
                    return $csvData.EmailAddress
                }
                else {
                    Write-Host "CSV file must contain 'EmailAddress' column" -ForegroundColor Red
                    return @()
                }
            }
            catch {
                Write-Host "Error reading CSV file: $($_.Exception.Message)" -ForegroundColor Red
                return @()
            }
        }
        else {
            Write-Host "CSV file not found: $input" -ForegroundColor Red
            return @()
        }
    }
    else {
        # Handle space-separated email addresses
        return $input -split '\s+' | Where-Object { $_ -ne "" }
    }
}

# Main script execution
Write-Host "=== Azure AD Group Management Tool ===" -ForegroundColor Cyan
Write-Host ""

# Get group name from user
$groupName = Read-Host "Enter the group name (Display Name or Mail Nickname)"

if ([string]::IsNullOrWhiteSpace($groupName)) {
    Write-Host "Group name cannot be empty" -ForegroundColor Red
    exit
}

# Find the group
$group = Get-AADGroupByName -GroupName $groupName

if (-not $group) {
    Write-Host "Group '$groupName' not found" -ForegroundColor Red
    exit
}

Write-Host "Found group: $($group.DisplayName)" -ForegroundColor Green
Write-Host "Group ID: $($group.ObjectId)" -ForegroundColor Gray
Write-Host ""

# Main menu loop
do {
    Write-Host "=== Options ===" -ForegroundColor Cyan
    Write-Host "1. Show members"
    Write-Host "2. Add members"
    Write-Host "3. Remove members"
    Write-Host "4. Exit"
    Write-Host ""
    
    $choice = Read-Host "Select an option (1-4)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "Enter search criteria:" -ForegroundColor Cyan
            Write-Host "(Type * to show all members, or enter name to search)" -ForegroundColor Gray
            $searchQuery = Read-Host "Search"
            
            if ([string]::IsNullOrWhiteSpace($searchQuery)) {
                $searchQuery = "*"
            }
            
            Show-GroupMembers -GroupObjectId $group.ObjectId -SearchQuery $searchQuery
        }
        
        "2" {
            $emailAddresses = Get-EmailAddressesFromInput
            if ($emailAddresses.Count -gt 0) {
                Add-GroupMembers -GroupObjectId $group.ObjectId -EmailAddresses $emailAddresses
            }
            else {
                Write-Host "No email addresses provided" -ForegroundColor Yellow
            }
        }
        
        "3" {
            $emailAddresses = Get-EmailAddressesFromInput
            if ($emailAddresses.Count -gt 0) {
                Remove-GroupMembers -GroupObjectId $group.ObjectId -EmailAddresses $emailAddresses
            }
            else {
                Write-Host "No email addresses provided" -ForegroundColor Yellow
            }
        }
        
        "4" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            break
        }
        
        default {
            Write-Host "Invalid option. Please select 1-4." -ForegroundColor Red
        }
    }
    
    if ($choice -ne "4") {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
        Write-Host "=== Azure AD Group Management Tool ===" -ForegroundColor Cyan
        Write-Host "Working with group: $($group.DisplayName)" -ForegroundColor Green
        Write-Host ""
    }
    
} while ($choice -ne "4")

Write-Host "Script completed." -ForegroundColor Green


<#
.SYNOPSIS
  Interactive Entra ID (Azure AD) group management by email/UPN on PowerShell 5.1,
  with CSV import support for bulk Add/Remove (with column headding EmailAddress).

.NOTES
  • Requires AzureAD module (Install-Module AzureAD)
  • Will prompt for Connect-AzureAD if not already connected
#>

param()  # prevent output when dot-sourced

# --- Import & Connect ---
if (-not (Get-Module -Name AzureAD)) {
    try { Import-Module AzureAD -ErrorAction Stop }
    catch {
        Write-Host "AzureAD module not found. Run 'Install-Module AzureAD' first." -ForegroundColor Red
        exit
    }
}
function Ensure-Connection {
    try {
        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Not connected to Azure AD; launching Connect-AzureAD..." -ForegroundColor Yellow
        Connect-AzureAD
    }
}

# --- Helpers ---
function Get-GroupByName {
    param([string]$Name)
    $filter = "displayName eq '$Name'"
    $groups = Get-AzureADGroup -Filter $filter
    if ($groups.Count -eq 1) { return $groups[0] }
    elseif ($groups.Count -gt 1) {
        Write-Host "Multiple groups named '$Name':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $groups.Count; $i++) {
            $g = $groups[$i]
            Write-Host "[$($i+1)] $($g.DisplayName) (Id: $($g.ObjectId))"
        }
        $sel = Read-Host "Enter number"
        if ($sel -as [int] -and $sel -ge 1 -and $sel -le $groups.Count) {
            return $groups[$sel - 1]
        }
    }
    return $null
}

function Get-UserById {
    param([string]$Id)
    if ($Id -match '^[0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12}$') {
        return Get-AzureADUser -ObjectId $Id -ErrorAction SilentlyContinue
    }
    if ($Id -match '@') {
        $u = Get-AzureADUser -Filter "userPrincipalName eq '$Id'" -ErrorAction SilentlyContinue
        if ($u) { return $u }
        return Get-AzureADUser -Filter "mail eq '$Id'" -ErrorAction SilentlyContinue
    }
    return Get-AzureADUser -Filter "userPrincipalName eq '$Id'" -ErrorAction SilentlyContinue
}

# Formatting
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

# --- Core Operations ---
function Show-Members {
    param(
        [string]   $GroupId,
        [string[]] $Terms
    )

    Write-Host "Loading members..." -ForegroundColor Cyan
    $members = Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User'
    $users = $members | ForEach-Object { Get-AzureADUser -ObjectId $_.ObjectId }

    $showAll = $Terms -contains '*'
    if ($showAll) {
        $ps   = Read-Host "Page size (or Enter for no paging)"
        $size = 0
        if ($ps -and ($ps -as [int]) -gt 0) { $size = [int]$ps }

        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
        Write-Host ("=" * 140)
        $count = 0
        foreach ($u in $users) {
            if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
            if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
            if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
            if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }

            Write-Host ($fmtData -f $dn,$eid,$em,$dp)
            $count++
            if ($size -gt 0 -and ($count % $size) -eq 0) {
                Write-Host ("-" * 140)
            }
        }
        Write-Host "Total: $count" -ForegroundColor Green
        return
    }

    Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)
    $found = 0; $no = @()
    foreach ($term in $Terms) {
        $pat = $term.ToLower()
        $matches = $users | Where-Object {
            ($_.DisplayName -and $_.DisplayName.ToLower().Contains($pat)) -or
            ($_.EmployeeId  -and $_.EmployeeId.ToLower().Contains($pat)) -or
            ($_.Mail        -and $_.Mail.ToLower().Contains($pat))
        }
        if ($matches) {
            foreach ($u in $matches) {
                if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
                if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
                if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
                if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }

                Write-Host ($fmtData -f $dn,$eid,$em,$dp)
                $found++
            }
        } else {
            Write-Host ($fmtStatus -f "✗ No match: $term") -ForegroundColor Yellow
            $no += $term
        }
    }
    Write-Host "Matched: $found" -ForegroundColor Green
    if ($no) { Write-Host "No matches: $($no -join ', ')" -ForegroundColor Yellow }
}

function Add-Members {
    param(
        [string]   $GroupId,
        [string[]] $Ids
    )
    Write-Host "Adding..." -ForegroundColor Cyan

    $cache = @{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User' |
      ForEach-Object {
          $u = Get-AzureADUser -ObjectId $_.ObjectId
          if ($u.UserPrincipalName) {
              $cache[$u.UserPrincipalName.ToLower()] = $u.ObjectId
          }
      }

    $added = @(); $already = @(); $failed = @()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)

    foreach ($id in $Ids) {
        $u = Get-UserById $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }

        if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
        if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
        if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
        if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }
        $upn = $u.UserPrincipalName.ToLower()

        if ($cache.ContainsKey($upn)) {
            Write-Host ($fmtStatus -f "⚠ Already:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $already += $id; continue
        }

        try {
            Add-AzureADGroupMember -ObjectId $GroupId -RefObjectId $u.ObjectId -ErrorAction Stop
            Write-Host ($fmtStatus -f "✓ Added:        ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
            $added += $id
            $cache[$upn] = $u.ObjectId
        }
        catch {
            Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $failed += $id
        }
    }

    Write-Host "Added: $($added.Count)  Already: $($already.Count)  Failed: $($failed.Count)" -ForegroundColor Cyan
}

function Remove-Members {
    param(
        [string]   $GroupId,
        [string[]] $Ids
    )
    Write-Host "Removing..." -ForegroundColor Cyan

    $cache = @{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User' |
      ForEach-Object {
          $u = Get-AzureADUser -ObjectId $_.ObjectId
          if ($u.UserPrincipalName) {
              $cache[$u.UserPrincipalName.ToLower()] = $u.ObjectId
          }
      }

    $removed = @(); $notmem = @(); $failed = @()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)

    foreach ($id in $Ids) {
        $u = Get-UserById $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }

        if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
        if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
        if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
        if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }
        $upn = $u.UserPrincipalName.ToLower()

        if (-not $cache.ContainsKey($upn)) {
            Write-Host ($fmtStatus -f "⚠ Not mem:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $notmem += $id; continue
        }

        try {
            Remove-AzureADGroupMember -ObjectId $GroupId -MemberId $cache[$upn] -ErrorAction Stop
            Write-Host ($fmtStatus -f "✓ Removed:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
            $removed += $id
            $cache.Remove($upn) | Out-Null
        }
        catch {
            Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $failed += $id
        }
    }

    Write-Host "Removed: $($removed.Count)  Not mem: $($notmem.Count)  Failed: $($failed.Count)" -ForegroundColor Cyan
}

# --- CSV/Manual Input Helper ---
function Get-InputIds {
    param([string]$msg)

    while ($true) {
        $v = Read-Host $msg
        if (-not $v) { Write-Host "Input required." -ForegroundColor Yellow; continue }

        $path = $v.Trim().Trim('"')
        try {
            $rp = Resolve-Path -Path $path -ErrorAction Stop
            $path = $rp.ProviderPath
        } catch {
            $rp = $null
        }

        if ($rp -and (Test-Path $path) -and ([IO.Path]::GetExtension($path) -ieq '.csv')) {
            try { $data = Import-Csv -Path $path -ErrorAction Stop }
            catch { Write-Host "CSV import failed." -ForegroundColor Red; continue }

            if ($data.Count -and $data[0].PSObject.Properties.Name -contains 'EmailAddress') {
                $ids = $data | ForEach-Object { $_.EmailAddress.Trim() } | Where-Object { $_ }
                if ($ids.Count) { return $ids }
            }
            Write-Host "CSV must have 'EmailAddress' column with data." -ForegroundColor Yellow
        } else {
            $ids = $v -split '\s+' | Where-Object { $_.Trim() }
            if ($ids.Count) { return $ids }
        }
    }
}

# --- Main ---
function Main {
    Ensure-Connection

    do {
        $name = Read-Host "Azure AD group DisplayName"
        $grp  = Get-GroupByName $name
    } until ($grp)
    $gid = $grp.ObjectId

    do {
        Write-Host "1) Show  2) Add  3) Remove"
        $choice = Read-Host "Choose (1-3)"
    } until ($choice -in '1','2','3')

    switch ($choice) {
        '1' {
            $t = Read-Host "Terms (space-separated) or *"
            Show-Members -GroupId $gid -Terms ($t -split '\s+' | Where-Object { $_ })
        }
        '2' {
            $ids = Get-InputIds "Provide emails/UPNs or CSV path"
            Add-Members    -GroupId $gid -Ids $ids
        }
        '3' {
            $ids = Get-InputIds "Provide emails/UPNs or CSV path"
            Remove-Members -GroupId $gid -Ids $ids
        }
    }

    Write-Host "Done." -ForegroundColor Green
}

# Run Main if invoked as a script
if ($PSCommandPath) {
    Main
}
