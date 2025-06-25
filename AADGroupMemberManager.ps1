<#
.SYNOPSIS
  Interactive Entra ID (Azure AD) group management by email/UPN on PowerShell 5.1.

.DESCRIPTION
  • Prompts for a valid Azure AD group name (DisplayName)  
  • Prompts until a valid action (1–3) is chosen:  
      1) Show Members  
      2) Add Members  
      3) Remove Members  
  • Show Members supports * or partial-match terms, with optional paging  
  • Add/Remove continues on errors  
  • Outputs aligned columns for Status, DisplayName, EmployeeId, Email, Department  
  • Color-coded feedback + summary

.NOTES
  - Requires AzureAD module  
  - Will prompt to Connect-AzureAD if no session detected  
  - Run as an account with proper Azure AD permissions  
#>

# Ensure AzureAD module is loaded and connected
if (-not (Get-Module -Name AzureAD)) {
    try {
        Import-Module AzureAD -ErrorAction Stop
    } catch {
        Write-Host "AzureAD module not found. Please install via 'Install-Module AzureAD' and re-run." -ForegroundColor Red
        return
    }
}

function Ensure-AzureADConnection {
    # Try a simple call; if it fails, prompt Connect-AzureAD
    try {
        # A lightweight call to verify connection
        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Not connected to Azure AD. Prompting for Connect-AzureAD..." -ForegroundColor Yellow
        Connect-AzureAD
    }
}

Ensure-AzureADConnection

# Helper: get a single group by display name, ensuring uniqueness
function Get-AzureADGroupByName {
    param([string]$DisplayName)
    # Use -Filter for exact match on displayName
    $filter = "displayName eq '$DisplayName'"
    $groups = Get-AzureADGroup -Filter $filter
    if (-not $groups) {
        return $null
    }
    elseif ($groups.Count -eq 1) {
        return $groups[0]
    }
    else {
        # Multiple groups share the same display name
        Write-Host "Multiple groups found with DisplayName '$DisplayName':" -ForegroundColor Yellow
        $idx = 1
        foreach ($g in $groups) {
            Write-Host "[$idx] DisplayName: $($g.DisplayName), ObjectId: $($g.ObjectId), MailEnabled: $($g.MailEnabled)" -ForegroundColor Cyan
            $idx++
        }
        $choice = Read-Host "Enter the number of the group you want"
        if ($choice -as [int] -and $choice -ge 1 -and $choice -le $groups.Count) {
            return $groups[$choice - 1]
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
            return $null
        }
    }
}

# Helper: get Azure AD user by identifier (email/UPN or objectId if GUID)
function Get-AADUserByIdentifier {
    param([string]$Identifier)
    # If looks like GUID, try Get-AzureADUser -ObjectId
    if ($Identifier -match '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$') {
        try {
            return Get-AzureADUser -ObjectId $Identifier -ErrorAction Stop
        } catch {
            return $null
        }
    }

    # If contains '@', treat as UPN or mail
    if ($Identifier -match '@') {
        # Try filter on userPrincipalName first, then mail
        $filterUPN = "userPrincipalName eq '$Identifier'"
        $user = Get-AzureADUser -Filter $filterUPN -ErrorAction SilentlyContinue
        if ($user) { return $user }

        $filterMail = "mail eq '$Identifier'"
        $user = Get-AzureADUser -Filter $filterMail -ErrorAction SilentlyContinue
        if ($user) { return $user }

        return $null
    } else {
        # Without '@', treat as UPN without domain? Could try principalName eq identifier
        $filterUPN = "userPrincipalName eq '$Identifier'"
        $user = Get-AzureADUser -Filter $filterUPN -ErrorAction SilentlyContinue
        if ($user) { return $user }
        # Could also try mail or displayName, but ambiguous; skip
        return $null
    }
}

# Column formats: Status=15, DisplayName=45, EmployeeId=15, Email=50, Department=20
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

function Show-Members {
    param(
        [string] $GroupObjectId,
        [string[]] $Terms
    )

    # Retrieve all members (paged internally)
    Write-Host "Retrieving all members of the group..." -ForegroundColor Cyan
    $allMembers = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true

    # For each member that is a user, fetch properties
    $allUsers = @()
    foreach ($m in $allMembers) {
        if ($m.ObjectType -eq 'User') {
            # Fetch full user object to get EmployeeId, Department, Mail, DisplayName
            try {
                $u = Get-AzureADUser -ObjectId $m.ObjectId
                $allUsers += $u
            } catch {
                # skip if cannot retrieve
            }
        }
    }

    $showAll = $Terms -contains '*'
    if ($showAll) {
        $pageSizeInput = Read-Host "Enter page size for visual grouping (or press Enter for continuous)"
        if ($pageSizeInput -and ($pageSizeInput -as [int]) -gt 0) {
            $pageSize = [int]$pageSizeInput
        } else {
            $pageSize = 0
        }

        Write-Host "Streaming all members:" -ForegroundColor Cyan
        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
        Write-Host ("=" * 140) -ForegroundColor Gray

        $count = 0
        foreach ($u in $allUsers) {
            $dn = if ($u.DisplayName)   { $u.DisplayName }   else { 'N/A' }
            $eid= if ($u.EmployeeId)    { $u.EmployeeId }    else { 'N/A' }
            $em = if ($u.Mail)          { $u.Mail }          else { 'N/A' }
            $dp = if ($u.Department)    { $u.Department }    else { 'N/A' }
            Write-Host ($fmtData -f $dn,$eid,$em,$dp)
            $count++
            if ($pageSize -gt 0 -and ($count % $pageSize) -eq 0) {
                Write-Host ("-" * 140) -ForegroundColor Gray
            }
        }

        Write-Host "Total members: $count" -ForegroundColor Green
        return
    }

    # Otherwise filter by terms
    Write-Host "Searching members for terms: $($Terms -join ', ')" -ForegroundColor Cyan
    Write-Host ($fmtData -f 'DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray

    $totalFound = 0
    $noMatch    = @()

    foreach ($term in $Terms) {
        $pattern = $term.ToLower()
        # Filter in PowerShell since Azure AD filter for partial match on multiple fields is complex; allUsers in memory
        $matches = $allUsers | Where-Object {
            ($_.DisplayName  -and $_.DisplayName.ToLower().Contains($pattern)) -or
            ($_.EmployeeId   -and $_.EmployeeId.ToLower().Contains($pattern)) -or
            ($_.Mail         -and $_.Mail.ToLower().Contains($pattern))
        }

        if ($matches) {
            foreach ($u in $matches) {
                $dn = if ($u.DisplayName)   { $u.DisplayName }   else { 'N/A' }
                $eid= if ($u.EmployeeId)    { $u.EmployeeId }    else { 'N/A' }
                $em = if ($u.Mail)          { $u.Mail }          else { 'N/A' }
                $dp = if ($u.Department)    { $u.Department }    else { 'N/A' }
                Write-Host ($fmtData -f $dn,$eid,$em,$dp)
                $totalFound++
            }
        }
        else {
            Write-Host ($fmtStatus -f "✗ No match: $term") -ForegroundColor Yellow
            $noMatch += $term
        }
    }

    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total matched: $totalFound" -ForegroundColor Green
    if ($noMatch) { Write-Host "No matches for: $($noMatch -join ', ')" -ForegroundColor Yellow }
}

function Add-Members {
    param(
        [string]   $GroupObjectId,
        [string[]] $Ids
    )
    Write-Host "Adding members to group (ObjectId: $GroupObjectId):" -ForegroundColor Cyan

    # Retrieve existing members' ObjectIds and build hash by UPN for quick check
    $existingMembers = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
    $existingHash = @{}
    foreach ($m in $existingMembers) {
        if ($m.ObjectType -eq 'User') {
            try {
                $u = Get-AzureADUser -ObjectId $m.ObjectId
                if ($u.UserPrincipalName) {
                    $existingHash[$u.UserPrincipalName.ToLower()] = $true
                }
            } catch {}
        }
    }

    $added   = @(); $already = @(); $failed = @()

    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray

    foreach ($id in $Ids) {
        $u = Get-AADUserByIdentifier $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }

        $dn = if ($u.DisplayName)   { $u.DisplayName }   else { 'N/A' }
        $eid= if ($u.EmployeeId)    { $u.EmployeeId }    else { 'N/A' }
        $em = if ($u.Mail)          { $u.Mail }          else { 'N/A' }
        $dp = if ($u.Department)    { $u.Department }    else { 'N/A' }
        $upn= if ($u.UserPrincipalName) { $u.UserPrincipalName } else { '' }

        if ($upn -and $existingHash.ContainsKey($upn.ToLower())) {
            Write-Host ($fmtStatus -f "⚠ Already:      ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $already += $id
        }
        else {
            try {
                Add-AzureADGroupMember -ObjectId $GroupObjectId -RefObjectId $u.ObjectId -ErrorAction Stop
                Write-Host ($fmtStatus -f "✓ Added:        ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
                $added += $id
            } catch {
                Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:     $($added.Count)"   -ForegroundColor Green
    Write-Host "Already:   $($already.Count)" -ForegroundColor Yellow
    Write-Host "Failed:    $($failed.Count)"  -ForegroundColor Yellow
}

function Remove-Members {
    param(
        [string]   $GroupObjectId,
        [string[]] $Ids
    )
    Write-Host "Removing members from group (ObjectId: $GroupObjectId):" -ForegroundColor Cyan

    # Retrieve existing members for quick check
    $existingMembers = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
    $existingHash = @{}
    foreach ($m in $existingMembers) {
        if ($m.ObjectType -eq 'User') {
            try {
                $u = Get-AzureADUser -ObjectId $m.ObjectId
                if ($u.UserPrincipalName) {
                    $existingHash[$u.UserPrincipalName.ToLower()] = $u.ObjectId
                }
            } catch {}
        }
    }

    $removed   = @(); $notMember = @(); $failed = @()

    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray

    foreach ($id in $Ids) {
        $u = Get-AADUserByIdentifier $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }

        $dn = if ($u.DisplayName)   { $u.DisplayName }   else { 'N/A' }
        $eid= if ($u.EmployeeId)    { $u.EmployeeId }    else { 'N/A' }
        $em = if ($u.Mail)          { $u.Mail }          else { 'N/A' }
        $dp = if ($u.Department)    { $u.Department }    else { 'N/A' }
        $upn= if ($u.UserPrincipalName) { $u.UserPrincipalName } else { '' }

        if (-not ($upn -and $existingHash.ContainsKey($upn.ToLower()))) {
            Write-Host ($fmtStatus -f "⚠ Not mem:      ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $notMember += $id
        }
        else {
            $userObjId = $existingHash[$upn.ToLower()]
            try {
                Remove-AzureADGroupMember -ObjectId $GroupObjectId -MemberId $userObjId -ErrorAction Stop
                Write-Host ($fmtStatus -f "✓ Removed:      ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
                $removed += $id
            }
            catch {
                Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed:   $($removed.Count)"   -ForegroundColor Green
    Write-Host "Not mem:   $($notMember.Count)" -ForegroundColor Yellow
    Write-Host "Failed:    $($failed.Count)"    -ForegroundColor Yellow
}

# --- Main Prompt Flow ---
do {
    $groupName = Read-Host "Enter the Azure AD group DisplayName"
    $groupObj = Get-AzureADGroupByName -DisplayName $groupName
    if (-not $groupObj) {
        Write-Host "Group '$groupName' not found or ambiguous. Please try again." -ForegroundColor Yellow
        $valid = $false
    } else {
        $valid = $true
    }
} until ($valid)

$groupId = $groupObj.ObjectId

do {
    Write-Host "Select an action:" -ForegroundColor Cyan
    Write-Host "  1) Show Members"
    Write-Host "  2) Add Members"
    Write-Host "  3) Remove Members"
    $choice = Read-Host "Enter choice (1-3)"
} until ($choice -in '1','2','3')

switch ($choice) {
    '1' {
        $input = Read-Host "Enter search terms (space-separated), or * for all"
        $terms = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Show-Members   -GroupObjectId $groupId -Terms $terms
    }
    '2' {
        $input = Read-Host "Enter identifiers (emails/UPNs) to add, separated by spaces"
        $ids    = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Add-Members    -GroupObjectId $groupId -Ids $ids
    }
    '3' {
        $input = Read-Host "Enter identifiers (emails/UPNs) to remove, separated by spaces"
        $ids    = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Remove-Members -GroupObjectId $groupId -Ids $ids
    }
}

Write-Host "Operation completed." -ForegroundColor Green
