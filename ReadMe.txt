<#
.SYNOPSIS
  Interactive AD-group management by email or SamAccountName on PowerShell 5.1.

.DESCRIPTION
  • Prompts for a valid AD group name  
  • Prompts until a valid action (1–3) is chosen:  
      1) Show Members  
      2) Add Members  
      3) Remove Members  
  • Show Members supports `*` or partial-match terms  
  • Add/Remove continues on errors  
  • Outputs aligned columns for Status, DisplayName, EmployeeNumber, Email, Department  
  • Color-coded feedback + summary

.NOTES
  - Requires ActiveDirectory module  
  - Run as Administrator  
#>

Import-Module ActiveDirectory

function Get-ADUserByIdentifier {
    param([string]$Identifier)
    $props = 'DisplayName','EmployeeNumber','Mail','Department','MemberOf'
    if ($Identifier -match '@') {
        return Get-ADUser -Filter "Mail -eq '$Identifier'" -Properties $props -ErrorAction SilentlyContinue
    } else {
        return Get-ADUser -Identity $Identifier -Properties $props -ErrorAction SilentlyContinue
    }
}

# --- column formats: status=15, DisplayName=45, EmployeeNumber=15, Email=50, Department=20 ---
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

function Show-Members {
    param(
        [string]   $GroupName,
        [string[]] $Terms
    )
    $showAll = $Terms -contains '*'

    if ($showAll) {
        $pageSize = Read-Host "Enter page size for visual grouping (or press Enter for continuous)"
        if ($pageSize -and ($pageSize -as [int]) -gt 0) { $pageSize = [int]$pageSize } else { $pageSize = 0 }

        Write-Host "`nStreaming all members of '$GroupName':" -ForegroundColor Cyan
        Write-Host ($fmtData -f 'DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
        Write-Host ("=" * 140) -ForegroundColor Gray

        $count = 0
        Get-ADGroupMember -Identity $GroupName | ForEach-Object {
            $u = Get-ADUser -Identity $_.DistinguishedName -Properties DisplayName,EmployeeNumber,Mail,Department
            $dn = $u.DisplayName     ? $u.DisplayName     : 'N/A'
            $en = $u.EmployeeNumber  ? $u.EmployeeNumber  : 'N/A'
            $em = $u.Mail            ? $u.Mail            : 'N/A'
            $dp = $u.Department      ? $u.Department      : 'N/A'
            Write-Host ($fmtData -f $dn,$en,$em,$dp)
            $count++
            if ($pageSize -gt 0 -and ($count % $pageSize) -eq 0) {
                Write-Host ("-" * 140) -ForegroundColor Gray
            }
        }

        Write-Host "`nTotal members: $count" -ForegroundColor Green
        return
    }

    Write-Host "`nSearching group '$GroupName' for terms: $($Terms -join ', ')" -ForegroundColor Cyan
    $allMembers = Get-ADGroupMember -Identity $GroupName -Recursive |
                  Get-ADUser -Properties DisplayName,EmployeeNumber,Mail,Department |
                  Select-Object DisplayName,EmployeeNumber,Mail,Department

    Write-Host ($fmtData -f 'DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray

    $totalFound = 0
    $noMatch    = @()

    foreach ($term in $Terms) {
        $pattern = "*$term*"
        $matches = $allMembers | Where-Object {
            $_.DisplayName    -like $pattern -or
            $_.EmployeeNumber -like $pattern -or
            $_.Mail           -like $pattern
        }

        if ($matches) {
            foreach ($u in $matches) {
                $dn = $u.DisplayName     ? $u.DisplayName     : 'N/A'
                $en = $u.EmployeeNumber  ? $u.EmployeeNumber  : 'N/A'
                $em = $u.Mail            ? $u.Mail            : 'N/A'
                $dp = $u.Department      ? $u.Department      : 'N/A'
                Write-Host ($fmtData -f $dn,$en,$em,$dp)
                $totalFound++
            }
        }
        else {
            Write-Host ($fmtStatus -f "✗ No match: $term") -ForegroundColor Yellow
            $noMatch += $term
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total matched: $totalFound" -ForegroundColor Green
    if ($noMatch) { Write-Host "No matches for: $($noMatch -join ', ')" -ForegroundColor Yellow }
}

function Add-Members {
    param(
        [string]   $GroupName,
        [string[]] $Ids
    )
    Write-Host "`nAdding members to '$GroupName':" -ForegroundColor Cyan

    $existing = @{}
    Get-ADGroupMember -Identity $GroupName | ForEach-Object { $existing[$_.SamAccountName] = $true }

    $added    = @(); $already = @(); $failed = @()

    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray

    foreach ($id in $Ids) {
        $u = Get-ADUserByIdentifier $id
        if (-not $u) {
            Write-Host ($fmtRow -f "✗ Not found",'N/A','N/A','N/A','N/A') -ForegroundColor Yellow
            $failed += $id; continue
        }

        $dn = $u.DisplayName     ? $u.DisplayName     : 'N/A'
        $en = $u.EmployeeNumber  ? $u.EmployeeNumber  : 'N/A'
        $em = $u.Mail            ? $u.Mail            : 'N/A'
        $dp = $u.Department      ? $u.Department      : 'N/A'

        if ($existing.ContainsKey($u.SamAccountName)) {
            Write-Host ($fmtRow -f "⚠ Already",$dn,$en,$em,$dp) -ForegroundColor Yellow
            $already += $id
        }
        else {
            try {
                Add-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host ($fmtRow -f "✓ Added",$dn,$en,$em,$dp) -ForegroundColor Green
                $added += $id
            } catch {
                Write-Host ($fmtRow -f "✗ Failed",$dn,$en,$em,$dp) -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:     $($added.Count)"   -ForegroundColor Green
    Write-Host "Already:   $($already.Count)" -ForegroundColor Yellow
    Write-Host "Failed:    $($failed.Count)"  -ForegroundColor Yellow
}

function Remove-Members {
    param(
        [string]   $GroupName,
        [string[]] $Ids
    )
    Write-Host "`nRemoving members from '$GroupName':" -ForegroundColor Cyan

    $existing   = @{}
    Get-ADGroupMember -Identity $GroupName | ForEach-Object { $existing[$_.SamAccountName] = $true }

    $removed    = @(); $notMember = @(); $failed = @()

    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
    Write-Host ("=" * 140) -ForegroundColor Gray

    foreach ($id in $Ids) {
        $u = Get-ADUserByIdentifier $id
        if (-not $u) {
            Write-Host ($fmtRow -f "✗ Not found",'N/A','N/A','N/A','N/A') -ForegroundColor Yellow
            $failed += $id; continue
        }

        $dn = $u.DisplayName     ? $u.DisplayName     : 'N/A'
        $en = $u.EmployeeNumber  ? $u.EmployeeNumber  : 'N/A'
        $em = $u.Mail            ? $u.Mail            : 'N/A'
        $dp = $u.Department      ? $u.Department      : 'N/A'

        if (-not $existing.ContainsKey($u.SamAccountName)) {
            Write-Host ($fmtRow -f "⚠ Not member",$dn,$en,$em,$dp) -ForegroundColor Yellow
            $notMember += $id
        }
        else {
            try {
                Remove-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host ($fmtRow -f "✓ Removed",$dn,$en,$em,$dp) -ForegroundColor Green
                $removed += $id
            }
            catch {
                Write-Host ($fmtRow -f "✗ Failed",$dn,$en,$em,$dp) -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed:   $($removed.Count)"   -ForegroundColor Green
    Write-Host "Not mem:   $($notMember.Count)" -ForegroundColor Yellow
    Write-Host "Failed:    $($failed.Count)"    -ForegroundColor Yellow
}

# — Main Prompt Flow — #

do {
    $group = Read-Host "`nEnter the AD group name"
    try { Get-ADGroup -Identity $group -ErrorAction Stop | Out-Null; $valid = $true }
    catch { Write-Host "Group '$group' not found. Please try again." -ForegroundColor Yellow; $valid = $false }
} until ($valid)

do {
    Write-Host "`nSelect an action:" -ForegroundColor Cyan
    Write-Host "  1) Show Members"
    Write-Host "  2) Add Members"
    Write-Host "  3) Remove Members"
    $choice = Read-Host "Enter choice (1-3)"
} until ($choice -in '1','2','3')

switch ($choice) {
    '1' {
        $input = Read-Host "Enter search terms (space-separated), or * for all"
        $terms = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Show-Members   -GroupName $group -Terms $terms
    }
    '2' {
        $input = Read-Host "Enter identifiers to add, separated by spaces"
        $ids    = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Add-Members    -GroupName $group -Ids $ids
    }
    '3' {
        $input = Read-Host "Enter identifiers to remove, separated by spaces"
        $ids    = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Remove-Members -GroupName $group -Ids $ids
    }
}

Write-Host "`nOperation completed." -ForegroundColor Green
