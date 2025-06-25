<#
.SYNOPSIS
  Interactive Entra ID (Azure AD) group management by email/UPN on PowerShell 5.1,
  with support for CSV import of EmailAddress column for add/remove operations.

.DESCRIPTION
  • Prompts for a valid Azure AD group name (DisplayName)
  • Prompts until a valid action (1–3) is chosen:
      1) Show Members
      2) Add Members
      3) Remove Members
  • Show Members supports * or partial-match terms, with optional paging
  • Add/Remove: supports manual input (space-separated emails/UPNs) or CSV file path
      with column heading `EmailAddress`. Continues on errors.
  • Outputs aligned columns for Status, DisplayName, EmployeeId, Email, Department
  • Color-coded feedback + summary

.NOTES
  - Requires AzureAD module
  - Will prompt to Connect-AzureAD if no session detected
  - Run as an account with proper Azure AD permissions
#>

param()  # prevent accidental output when dot-sourcing

# Import & connection check
if (-not (Get-Module -Name AzureAD)) {
    try { Import-Module AzureAD -ErrorAction Stop }
    catch {
        Write-Host "AzureAD module not found. Install via 'Install-Module AzureAD'." -ForegroundColor Red
        return
    }
}

function Ensure-AzureADConnection {
    try { Get-AzureADTenantDetail -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "Not connected to Azure AD. Prompting Connect-AzureAD..." -ForegroundColor Yellow
        Connect-AzureAD
    }
}

function Get-AzureADGroupByName {
    param([string]$DisplayName)
    $filter = "displayName eq '$DisplayName'"
    $groups = Get-AzureADGroup -Filter $filter
    if (-not $groups) { return $null }
    elseif ($groups.Count -eq 1) { return $groups[0] }
    else {
        Write-Host "Multiple groups named '$DisplayName':" -ForegroundColor Yellow
        $i = 1
        foreach ($g in $groups) {
            Write-Host "[$i] DisplayName: $($g.DisplayName), Id: $($g.ObjectId), MailEnabled: $($g.MailEnabled)" -ForegroundColor Cyan
            $i++
        }
        $choice = Read-Host "Enter the number of the group to manage"
        if ($choice -as [int] -and $choice -ge 1 -and $choice -le $groups.Count) {
            return $groups[$choice - 1]
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
            return $null
        }
    }
}

function Get-AADUserByIdentifier {
    param([string]$Identifier)
    # GUID?
    if ($Identifier -match '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$') {
        try { return Get-AzureADUser -ObjectId $Identifier -ErrorAction Stop }
        catch { return $null }
    }
    if ($Identifier -match '@') {
        # Try UPN first, then mail
        $u = Get-AzureADUser -Filter "userPrincipalName eq '$Identifier'" -ErrorAction SilentlyContinue
        if ($u) { return $u }
        $u = Get-AzureADUser -Filter "mail eq '$Identifier'" -ErrorAction SilentlyContinue
        return $u
    } else {
        # Try exact UPN match (rare without domain), else null
        $u = Get-AzureADUser -Filter "userPrincipalName eq '$Identifier'" -ErrorAction SilentlyContinue
        return $u
    }
}

# Formatting strings
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

function Show-Members {
    param(
        [string] $GroupObjectId,
        [string[]] $Terms
    )
    Write-Host "Retrieving all members..." -ForegroundColor Cyan
    $allMembers = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
    $allUsers = @()
    foreach ($m in $allMembers) {
        if ($m.ObjectType -eq 'User') {
            try { $allUsers += Get-AzureADUser -ObjectId $m.ObjectId } catch {}
        }
    }

    $showAll = $Terms -contains '*'
    if ($showAll) {
        $ps = Read-Host "Enter page size for visual grouping (or press Enter for continuous)"
        if ($ps -and ($ps -as [int]) -gt 0) { $pageSize = [int]$ps } else { $pageSize = 0 }
        Write-Host "Streaming all members:" -ForegroundColor Cyan
        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
        Write-Host ("=" * 140) -ForegroundColor Gray
        $count = 0
        foreach ($u in $allUsers) {
            $dn  = if ($u.DisplayName) { $u.DisplayName } else { 'N/A' }
            $eid = if ($u.EmployeeId)  { $u.EmployeeId }  else { 'N/A' }
            $em  = if ($u.Mail)        { $u.Mail }        else { 'N/A' }
            $dp  = if ($u.Department)  { $u.Department }  else { 'N/A' }
            Write-Host ($fmtData -f $dn,$eid,$em,$dp)
            $count++
            if ($pageSize -gt 0 -and ($count % $pageSize) -eq 0) {
                Write-Host ("-" * 140) -ForegroundColor Gray
            }
        }
        Write-Host "Total members: $count" -ForegroundColor Green
        return
    }

    Write-Host "Searching members for terms: $($Terms -join ', ')" -ForegroundColor Cyan
    Write-Host ($fmtData -f 'DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray
    $totalFound = 0; $noMatch = @()
    foreach ($term in $Terms) {
        $p = $term.ToLower()
        $matches = $allUsers | Where-Object {
            ($_.DisplayName -and $_.DisplayName.ToLower().Contains($p)) -or
            ($_.EmployeeId  -and $_.EmployeeId.ToLower().Contains($p)) -or
            ($_.Mail        -and $_.Mail.ToLower().Contains($p))
        }
        if ($matches) {
            foreach ($u in $matches) {
                $dn  = if ($u.DisplayName) { $u.DisplayName } else { 'N/A' }
                $eid = if ($u.EmployeeId)  { $u.EmployeeId }  else { 'N/A' }
                $em  = if ($u.Mail)        { $u.Mail }        else { 'N/A' }
                $dp  = if ($u.Department)  { $u.Department }  else { 'N/A' }
                Write-Host ($fmtData -f $dn,$eid,$em,$dp)
                $totalFound++
            }
        } else {
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
    $existing = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
    $existingHash = @{}
    foreach ($m in $existing) {
        if ($m.ObjectType -eq 'User') {
            try {
                $u=Get-AzureADUser -ObjectId $m.ObjectId
                if ($u.UserPrincipalName) { $existingHash[$u.UserPrincipalName.ToLower()] = $true }
            } catch {}
        }
    }
    $added=@(); $already=@(); $failed=@()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray
    foreach ($id in $Ids) {
        $u = Get-AADUserByIdentifier $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }
        $dn  = if ($u.DisplayName) { $u.DisplayName } else { 'N/A' }
        $eid = if ($u.EmployeeId)  { $u.EmployeeId }  else { 'N/A' }
        $em  = if ($u.Mail)        { $u.Mail }        else { 'N/A' }
        $dp  = if ($u.Department)  { $u.Department }  else { 'N/A' }
        $upn = if ($u.UserPrincipalName) { $u.UserPrincipalName } else { '' }
        if ($upn -and $existingHash.ContainsKey($upn.ToLower())) {
            Write-Host ($fmtStatus -f "⚠ Already:      ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $already += $id
        } else {
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
    $existing = Get-AzureADGroupMember -ObjectId $GroupObjectId -All $true
    $existingHash = @{}
    foreach ($m in $existing) {
        if ($m.ObjectType -eq 'User') {
            try {
                $u=Get-AzureADUser -ObjectId $m.ObjectId
                if ($u.UserPrincipalName) { $existingHash[$u.UserPrincipalName.ToLower()] = $u.ObjectId }
            } catch {}
        }
    }
    $removed=@(); $notMember=@(); $failed=@()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray
    foreach ($id in $Ids) {
        $u = Get-AADUserByIdentifier $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }
        $dn  = if ($u.DisplayName) { $u.DisplayName } else { 'N/A' }
        $eid = if ($u.EmployeeId)  { $u.EmployeeId }  else { 'N/A' }
        $em  = if ($u.Mail)        { $u.Mail }        else { 'N/A' }
        $dp  = if ($u.Department)  { $u.Department }  else { 'N/A' }
        $upn = if ($u.UserPrincipalName) { $u.UserPrincipalName } else { '' }
        if (-not ($upn -and $existingHash.ContainsKey($upn.ToLower()))) {
            Write-Host ($fmtStatus -f "⚠ Not mem:      ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $notMember += $id
        } else {
            $userObjId = $existingHash[$upn.ToLower()]
            try {
                Remove-AzureADGroupMember -ObjectId $GroupObjectId -MemberId $userObjId -ErrorAction Stop
                Write-Host ($fmtStatus -f "✓ Removed:      ") -NoNewline; Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
                $removed += $id
            } catch {
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

# New helper: prompt user and return array of identifiers (emails/UPNs)
function Get-IdentifiersFromInput {
    param([string]$PromptMessage)

    while ($true) {
        $input = Read-Host $PromptMessage
        if (-not $input) {
            Write-Host "No input provided. Please enter space-separated emails/UPNs or a CSV file path." -ForegroundColor Yellow
            continue
        }
        # If path exists and is a .csv, try import
        if (Test-Path $input) {
            $ext = [IO.Path]::GetExtension($input)
            if ($ext -ieq '.csv') {
                try {
                    $rows = Import-Csv -Path $input -ErrorAction Stop
                } catch {
                    Write-Host "Failed to import CSV at path '$input'. Please check the file." -ForegroundColor Red
                    continue
                }
                if ($rows.Count -eq 0) {
                    Write-Host "CSV is empty. Please provide a CSV with a header 'EmailAddress' and at least one row." -ForegroundColor Yellow
                    continue
                }
                if (-not ($rows[0].PSObject.Properties.Name -contains 'EmailAddress')) {
                    Write-Host "CSV does not contain an 'EmailAddress' column. Please ensure header is exactly 'EmailAddress'." -ForegroundColor Red
                    continue
                }
                # Extract and trim non-empty emails
                $ids = $rows | ForEach-Object { $_.EmailAddress.Trim() } | Where-Object { $_ -and $_.Trim() -ne '' }
                if ($ids.Count -eq 0) {
                    Write-Host "No valid EmailAddress values found in CSV. Please check the file." -ForegroundColor Yellow
                    continue
                }
                return $ids
            } else {
                Write-Host "Path '$input' exists but is not a CSV file. Please provide a .csv file or manual input." -ForegroundColor Yellow
                continue
            }
        }
        else {
            # Treat as manual space-separated list
            $ids = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
            if ($ids.Count -gt 0) {
                return $ids
            } else {
                Write-Host "No valid identifiers detected. Please try again." -ForegroundColor Yellow
                continue
            }
        }
    }
}

function Main {
    Ensure-AzureADConnection

    # Prompt for group
    do {
        $gName = Read-Host "Enter the Azure AD group DisplayName"
        $gObj = Get-AzureADGroupByName -DisplayName $gName
        if (-not $gObj) {
            Write-Host "Group '$gName' not found or ambiguous. Try again." -ForegroundColor Yellow
            $ok = $false
        } else { $ok = $true }
    } until ($ok)
    $groupId = $gObj.ObjectId

    # Prompt for action
    do {
        Write-Host "Select an action:" -ForegroundColor Cyan
        Write-Host "  1) Show Members"
        Write-Host "  2) Add Members"
        Write-Host "  3) Remove Members"
        $choice = Read-Host "Enter choice (1-3)"
    } until ($choice -in '1','2','3')

    switch ($choice) {
        '1' {
            $inp = Read-Host "Enter search terms (space-separated), or * for all"
            $terms = $inp -split '\s+' | Where-Object { $_.Trim() -ne '' }
            Show-Members -GroupObjectId $groupId -Terms $terms
        }
        '2' {
            $ids = Get-IdentifiersFromInput "Enter identifiers to ADD: space-separated emails/UPNs, or path to CSV file with 'EmailAddress' column"
            Add-Members -GroupObjectId $groupId -Ids $ids
        }
        '3' {
            $ids = Get-IdentifiersFromInput "Enter identifiers to REMOVE: space-separated emails/UPNs, or path to CSV file with 'EmailAddress' column"
            Remove-Members -GroupObjectId $groupId -Ids $ids
        }
    }

    Write-Host "Operation completed." -ForegroundColor Green
}

# Only invoke when script is run, not when dot-sourced
if ($MyInvocation.ScriptName) {
    Main
}
