#
# Interactive AD-group management by email address or SamAccountName.
# Enhanced with DisplayName, EmployeeNumber, Email, Department output.
#

Import-Module ActiveDirectory

# Helper: resolve user by email or SamAccountName with all needed properties
function Get-ADUserByIdentifier {
    param([string]$Identifier)
    
    $props = 'DisplayName','EmployeeNumber','Mail','Department'
    
    try {
        if ($Identifier -match '@') {
            # Use scriptblock syntax to prevent LDAP injection
            return Get-ADUser -Filter {Mail -eq $Identifier} -Properties $props -ErrorAction Stop
        }
        else {
            return Get-ADUser -Identity $Identifier -Properties $props -ErrorAction Stop
        }
    }
    catch {
        return $null
    }
}

# Helper: check if user is member of group (direct membership only)
function Test-UserInGroup {
    param(
        [string]$UserSamAccountName,
        [hashtable]$ExistingMembers
    )
    
    return $ExistingMembers.ContainsKey($UserSamAccountName)
}

# Show-Members: streams all members or checks specific users
function Show-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )

    $showAll = $Identifiers -contains '*'
    $found = @(); $notFound = @(); $notInGroup = @()

    if ($showAll) {
        Write-Host "`nStreaming all members of '$GroupName':" -ForegroundColor Cyan
        Write-Host "DisplayName | EmployeeNumber | Email | Department" -ForegroundColor Gray
        Write-Host ("=" * 80) -ForegroundColor Gray
        
        $count = 0
        try {
            Get-ADGroupMember -Identity $GroupName | ForEach-Object {
                $u = Get-ADUser -Identity $_.DistinguishedName -Properties DisplayName,EmployeeNumber,Mail,Department -ErrorAction SilentlyContinue
                if ($u) {
                    $displayName = $u.DisplayName ?? "N/A"
                    $empNumber = $u.EmployeeNumber ?? "N/A"  
                    $email = $u.Mail ?? "N/A"
                    $dept = $u.Department ?? "N/A"
                    Write-Host "$displayName | $empNumber | $email | $dept"
                    $count++
                }
            }
        }
        catch {
            Write-Host "Error retrieving group members: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
        
        Write-Host "`nTotal members: $count" -ForegroundColor Green
        return
    }

    Write-Host "`nChecking specified identifiers..." -ForegroundColor Cyan
    
    # Get existing members for efficient lookup
    $existingMembers = @{}
    try {
        Get-ADGroupMember -Identity $GroupName | ForEach-Object {
            $existingMembers[$_.SamAccountName] = $true
        }
    }
    catch {
        Write-Host "Error retrieving group members: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    foreach ($id in $Identifiers) {
        $user = Get-ADUserByIdentifier $id
        
        if (-not $user) {
            Write-Host "✗ Not found: $id" -ForegroundColor Red
            $notFound += $id
            continue
        }

        # Check direct membership only
        if (Test-UserInGroup -UserSamAccountName $user.SamAccountName -ExistingMembers $existingMembers) {
            $displayName = $user.DisplayName ?? "N/A"
            $empNumber = $user.EmployeeNumber ?? "N/A"
            $email = $user.Mail ?? "N/A" 
            $dept = $user.Department ?? "N/A"
            Write-Host "✓ In group: $displayName | $empNumber | $email | $dept" -ForegroundColor Green
            $found += $id
        }
        else {
            $displayName = $user.DisplayName ?? "N/A"
            $empNumber = $user.EmployeeNumber ?? "N/A"
            $email = $user.Mail ?? "N/A"
            $dept = $user.Department ?? "N/A"
            Write-Host "⚠ Not in group: $displayName | $empNumber | $email | $dept" -ForegroundColor Yellow
            $notInGroup += $id
        }
    }

    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "In Group:     $($found.Count)" -ForegroundColor Green
    Write-Host "Not in Group: $($notInGroup.Count)" -ForegroundColor Yellow
    Write-Host "Not Found:    $($notFound.Count)" -ForegroundColor Red
}

# Add-Members: adds users with detailed reporting
function Add-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )

    Write-Host "`nAdding members to '$GroupName':" -ForegroundColor Cyan
    
    # Cache existing members for efficiency
    $existingMembers = @{}
    try {
        Get-ADGroupMember -Identity $GroupName | ForEach-Object {
            $existingMembers[$_.SamAccountName] = $true
        }
    }
    catch {
        Write-Host "Error retrieving existing members: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $added = @(); $already = @(); $failed = @()

    foreach ($id in $Identifiers) {
        $u = Get-ADUserByIdentifier $id
        
        if (-not $u) {
            Write-Host "✗ Not found: $id" -ForegroundColor Red
            $failed += $id
            continue
        }

        $displayName = $u.DisplayName ?? "N/A"
        $empNumber = $u.EmployeeNumber ?? "N/A"
        $email = $u.Mail ?? "N/A"
        $dept = $u.Department ?? "N/A"
        $userInfo = "$displayName | $empNumber | $email | $dept"

        if ($existingMembers.ContainsKey($u.SamAccountName)) {
            Write-Host "⚠ Already member: $userInfo" -ForegroundColor Yellow
            $already += $id
        }
        else {
            try {
                Add-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "✓ Added: $userInfo" -ForegroundColor Green
                $added += $id
            }
            catch {
                Write-Host "✗ Failed adding $id — $($_.Exception.Message)" -ForegroundColor Red
                $failed += $id
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:          $($added.Count)" -ForegroundColor Green
    Write-Host "Already Member: $($already.Count)" -ForegroundColor Yellow
    Write-Host "Failed:         $($failed.Count)" -ForegroundColor Red
}

# Remove-Members: removes users with detailed reporting  
function Remove-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )

    Write-Host "`nRemoving members from '$GroupName':" -ForegroundColor Cyan
    
    # Cache existing members
    $existingMembers = @{}
    try {
        Get-ADGroupMember -Identity $GroupName | ForEach-Object {
            $existingMembers[$_.SamAccountName] = $true
        }
    }
    catch {
        Write-Host "Error retrieving existing members: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $removed = @(); $notMember = @(); $failed = @()

    foreach ($id in $Identifiers) {
        $u = Get-ADUserByIdentifier $id
        
        if (-not $u) {
            Write-Host "✗ Not found: $id" -ForegroundColor Red
            $failed += $id
            continue
        }

        $displayName = $u.DisplayName ?? "N/A"
        $empNumber = $u.EmployeeNumber ?? "N/A"
        $email = $u.Mail ?? "N/A"
        $dept = $u.Department ?? "N/A"
        $userInfo = "$displayName | $empNumber | $email | $dept"

        if (-not $existingMembers.ContainsKey($u.SamAccountName)) {
            Write-Host "⚠ Not a member: $userInfo" -ForegroundColor Yellow
            $notMember += $id
        }
        else {
            try {
                Remove-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "✓ Removed: $userInfo" -ForegroundColor Green
                $removed += $id
            }
            catch {
                Write-Host "✗ Failed removing $id — $($_.Exception.Message)" -ForegroundColor Red
                $failed += $id
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed:    $($removed.Count)" -ForegroundColor Green
    Write-Host "Not Member: $($notMember.Count)" -ForegroundColor Yellow
    Write-Host "Failed:     $($failed.Count)" -ForegroundColor Red
}

# Main execution
do {
    $group = Read-Host "`nEnter the AD group name"
    try {
        Get-ADGroup -Identity $group -ErrorAction Stop | Out-Null
        $valid = $true
    } 
    catch {
        Write-Host "Group '$group' not found. Please try again." -ForegroundColor Red
        $valid = $false
    }
} until ($valid)

Write-Host "`nSelect an action:" -ForegroundColor Cyan
Write-Host "  1) Show Members (enter * for all, or specific emails/usernames)"
Write-Host "  2) Add Members" 
Write-Host "  3) Remove Members"

$choice = Read-Host "`nEnter choice (1-3)"

switch ($choice) {
    '1' {
        $input = Read-Host "Enter identifiers (emails/usernames) separated by spaces, or *"
        $ids = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        if ($ids) { Show-Members -GroupName $group -Identifiers $ids }
        else { Write-Host "No identifiers provided." -ForegroundColor Yellow }
    }
    '2' {
        $input = Read-Host "Enter identifiers to add, separated by spaces"
        $ids = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        if ($ids) { Add-Members -GroupName $group -Identifiers $ids }
        else { Write-Host "No identifiers provided." -ForegroundColor Yellow }
    }
    '3' {
        $input = Read-Host "Enter identifiers to remove, separated by spaces"
        $ids = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        if ($ids) { Remove-Members -GroupName $group -Identifiers $ids }
        else { Write-Host "No identifiers provided." -ForegroundColor Yellow }
    }
    default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nOperation completed." -ForegroundColor Green
