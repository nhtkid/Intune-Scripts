<#
.SYNOPSIS
  Interactive AD-group management by email or SamAccountName.

.DESCRIPTION
  • Prompts for a valid AD group name  
  • Then loops until you pick a valid action (1–3):  
      1) Show Members  
      2) Add Members  
      3) Remove Members  
  • Show Members: accepts `*` or a list of identifiers, streams as it goes  
      – You can enter a page size to visually separate output blocks  
  • Add/Remove: accepts a list of identifiers (no `*`), continues on errors  
  • Outputs DisplayName, EmployeeNumber, Email, Department  
  • Color-coded feedback + summary

.NOTES
  - Assumes the ActiveDirectory module is already loaded  
  - Run as Administrator  
#>

Import-Module ActiveDirectory

function Get-ADUserByIdentifier {
    param([string]$Identifier)
    $props = 'DisplayName','EmployeeNumber','Mail','Department','MemberOf'
    if ($Identifier -match '@') {
        return Get-ADUser -Filter "Mail -eq '$Identifier'" -Properties $props -ErrorAction SilentlyContinue
    }
    else {
        return Get-ADUser -Identity $Identifier -Properties $props -ErrorAction SilentlyContinue
    }
}

function Show-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )

    $showAll = $Identifiers -contains '*'
    # get group DN once
    $groupDN = (Get-ADGroup -Identity $GroupName -ErrorAction Stop).DistinguishedName

    if ($showAll) {
        $pageSize = Read-Host "Enter page size for visual grouping (or press Enter for continuous)"
        if ($pageSize -and ($pageSize -as [int]) -gt 0) {
            $pageSize = [int]$pageSize
        } else { $pageSize = 0 }

        Write-Host "`nStreaming all members of '$GroupName':" -ForegroundColor Cyan
        Write-Host "DisplayName | EmployeeNumber | Email | Department" -ForegroundColor Gray
        Write-Host ("=" * 80) -ForegroundColor Gray

        $count = 0
        Get-ADGroupMember -Identity $GroupName | ForEach-Object {
            $u = Get-ADUser -Identity $_.DistinguishedName -Properties DisplayName,EmployeeNumber,Mail,Department
            $dn = $u.DisplayName  ?? 'N/A'
            $en = $u.EmployeeNumber ?? 'N/A'
            $em = $u.Mail           ?? 'N/A'
            $dp = $u.Department     ?? 'N/A'
            Write-Host "$dn | $en | $em | $dp"
            $count++
            if ($pageSize -gt 0 -and ($count % $pageSize) -eq 0) {
                Write-Host ("-" * 80) -ForegroundColor Gray
            }
        }

        Write-Host "`nTotal members: $count" -ForegroundColor Green
        return
    }

    # specific identifiers
    Write-Host "`nChecking specified identifiers..." -ForegroundColor Cyan
    # cache direct members
    $existing = @{}
    Get-ADGroupMember -Identity $GroupName | ForEach-Object {
        $existing[$_.SamAccountName] = $true
    }

    $found = @(); $notIn = @(); $notFound = @()
    foreach ($id in $Identifiers) {
        $u = Get-ADUserByIdentifier $id
        if (-not $u) {
            Write-Host "✗ Not found: $id" -ForegroundColor Yellow
            $notFound += $id; continue
        }

        $dn = $u.DisplayName  ?? 'N/A'
        $en = $u.EmployeeNumber ?? 'N/A'
        $em = $u.Mail           ?? 'N/A'
        $dp = $u.Department     ?? 'N/A'
        $info = "$dn | $en | $em | $dp"

        if ($existing.ContainsKey($u.SamAccountName)) {
            Write-Host "✓ In group:     $info" -ForegroundColor Green
            $found += $id
        } else {
            Write-Host "⚠ Not in group: $info" -ForegroundColor Yellow
            $notIn += $id
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "In Group:     $($found.Count)" -ForegroundColor Green
    Write-Host "Not in Group: $($notIn.Count)" -ForegroundColor Yellow
    Write-Host "Not Found:    $($notFound.Count)" -ForegroundColor Yellow
}

function Add-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )
    Write-Host "`nAdding members to '$GroupName':" -ForegroundColor Cyan

    $existing = @{}
    Get-ADGroupMember -Identity $GroupName | ForEach-Object {
        $existing[$_.SamAccountName] = $true
    }

    $added = @(); $already = @(); $failed = @()
    foreach ($id in $Identifiers) {
        $u = Get-ADUserByIdentifier $id
        if (-not $u) {
            Write-Host "✗ Not found: $id" -ForegroundColor Yellow
            $failed += $id; continue
        }

        $dn = $u.DisplayName  ?? 'N/A'
        $en = $u.EmployeeNumber ?? 'N/A'
        $em = $u.Mail           ?? 'N/A'
        $dp = $u.Department     ?? 'N/A'
        $info = "$dn | $en | $em | $dp"

        if ($existing.ContainsKey($u.SamAccountName)) {
            Write-Host "⚠ Already member: $info" -ForegroundColor Yellow
            $already += $id
        } else {
            try {
                Add-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "✓ Added: $info" -ForegroundColor Green
                $added += $id
            } catch {
                Write-Host "✗ Failed adding $id — $($_.Exception.Message)" -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:          $($added.Count)"         -ForegroundColor Green
    Write-Host "Already Member: $($already.Count)"       -ForegroundColor Yellow
    Write-Host "Failed:         $($failed.Count)"        -ForegroundColor Yellow
}

function Remove-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )
    Write-Host "`nRemoving members from '$GroupName':" -ForegroundColor Cyan

    $existing = @{}
    Get-ADGroupMember -Identity $GroupName | ForEach-Object {
        $existing[$_.SamAccountName] = $true
    }

    $removed = @(); $notMember = @(); $failed = @()
    foreach ($id in $Identifiers) {
        $u = Get-ADUserByIdentifier $id
        if (-not $u) {
            Write-Host "✗ Not found: $id" -ForegroundColor Yellow
            $failed += $id; continue
        }

        $dn = $u.DisplayName  ?? 'N/A'
        $en = $u.EmployeeNumber ?? 'N/A'
        $em = $u.Mail           ?? 'N/A'
        $dp = $u.Department     ?? 'N/A'
        $info = "$dn | $en | $em | $dp"

        if (-not $existing.ContainsKey($u.SamAccountName)) {
            Write-Host "⚠ Not a member: $info" -ForegroundColor Yellow
            $notMember += $id
        } else {
            try {
                Remove-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "✓ Removed: $info" -ForegroundColor Green
                $removed += $id
            } catch {
                Write-Host "✗ Failed removing $id — $($_.Exception.Message)" -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed:    $($removed.Count)"    -ForegroundColor Green
    Write-Host "Not Member: $($notMember.Count)" -ForegroundColor Yellow
    Write-Host "Failed:     $($failed.Count)"    -ForegroundColor Yellow
}

# — Main Prompt Flow — #

# 1) Group name
do {
    $group = Read-Host "`nEnter the AD group name"
    try {
        Get-ADGroup -Identity $group -ErrorAction Stop | Out-Null
        $valid = $true
    } catch {
        Write-Host "Group '$group' not found. Please try again." -ForegroundColor Yellow
        $valid = $false
    }
} until ($valid)

# 2) Action menu (re-prompt on invalid)
do {
    Write-Host "`nSelect an action:" -ForegroundColor Cyan
    Write-Host "  1) Show Members"
    Write-Host "  2) Add Members"
    Write-Host "  3) Remove Members"
    $choice = Read-Host "Enter choice (1-3)"
} until ($choice -in '1','2','3')

# 3) Dispatch
switch ($choice) {
    '1' {
        $input = Read-Host "Enter identifiers separated by spaces, or * for all"
        $ids   = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Show-Members   -GroupName $group -Identifiers $ids
    }
    '2' {
        $input = Read-Host "Enter identifiers to add, separated by spaces"
        $ids   = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Add-Members    -GroupName $group -Identifiers $ids
    }
    '3' {
        $input = Read-Host "Enter identifiers to remove, separated by spaces"
        $ids   = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Remove-Members -GroupName $group -Identifiers $ids
    }
}

Write-Host "`nOperation completed." -ForegroundColor Green
