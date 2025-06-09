<#
.SYNOPSIS
  Interactive AD-group management: show, add, or remove members.
.DESCRIPTION
  - Prompts for a valid AD group name
  - Prompts for an action: Show (filter or all), Add, or Remove
  - Streams output to console with aligned columns and color-coded statuses
  - Fetches all user details in a single batched query for performance
  - Displays summary counts at end
.NOTES
  - Requires ActiveDirectory module
  - Designed for PowerShell 5.1
#>

# Ensure errors stop execution for clearer error handling
$ErrorActionPreference = 'Stop'

Import-Module ActiveDirectory -ErrorAction Stop

# Predefine column formats
$width = $Host.UI.RawUI.BufferSize.Width
$colStatus = 15
$colData = ($width - $colStatus - 4) / 4  # evenly split remaining columns

$fmtStatus = "{0,-$colStatus}"
$fmtData   = "{0,-$colData} {1,-$colData} {2,-$colData} {3,-$colData}"
$fmtRow    = "$fmtStatus $fmtData"

function Show-Members {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]   $GroupName,
        [Parameter(Mandatory)] [string[]] $Terms
    )
    # Get all member DNs and batch-fetch user properties
    Write-Host "`nRetrieving members of '$GroupName'..." -ForegroundColor Cyan
    $dns = Get-ADGroupMember -Identity $GroupName | Select-Object -ExpandProperty DistinguishedName
    if (-not $dns) {
        Write-Warning "Group '$GroupName' has no members."
        return
    }
    $users = Get-ADUser -Filter "DistinguishedName -in \$dns" -Properties DisplayName,EmployeeNumber,Mail,Department

    # Prepare output header
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
    Write-Host (('=' * $width)) -ForegroundColor Gray

    $total = 0; $noMatch = @()
    $showAll = $Terms -contains '*'

    if ($showAll) {
        foreach ($u in $users) {
            $dn = $u.DisplayName  -or 'N/A'
            $en = $u.EmployeeNumber -or 'N/A'
            $em = $u.Mail           -or 'N/A'
            $dp = $u.Department     -or 'N/A'
            Write-Host ($fmtRow -f '','"$dn"',$en,$em,$dp)
            $total++
        }
    } else {
        foreach ($term in $Terms) {
            $pattern = "$term"
            $matches = $users | Where-Object {
                $_.DisplayName    -like "*$pattern*" -or
                $_.EmployeeNumber -like "*$pattern*" -or
                $_.Mail           -like "*$pattern*"
            }
            if ($matches) {
                foreach ($u in $matches) {
                    $dn = $u.DisplayName  -or 'N/A'
                    $en = $u.EmployeeNumber -or 'N/A'
                    $em = $u.Mail           -or 'N/A'
                    $dp = $u.Department     -or 'N/A'
                    Write-Host ($fmtRow -f '','"$dn"',$en,$em,$dp)
                    $total++
                }
            } else {
                Write-Host ($fmtStatus -f "✗ No match: $term") -ForegroundColor Yellow
                $noMatch += $term
            }
        }
    }

    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total displayed: $total" -ForegroundColor Green
    if ($noMatch) { Write-Host "No matches for: $($noMatch -join ', ')" -ForegroundColor Yellow }
}

function Add-Members {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]   $GroupName,
        [Parameter(Mandatory)] [string[]] $Ids
    )
    Write-Host "`nAdding to '$GroupName':" -ForegroundColor Cyan
    # Track existing members
    $existing = Get-ADGroupMember -Identity $GroupName | Select-Object -ExpandProperty SamAccountName

    # Batch-fetch users by Identity or Mail
    $users = @{}
    foreach ($id in $Ids) {
        $u = if ($id -match '@') {
            Get-ADUser -Filter "Mail -eq '$id'" -Properties SamAccountName,DisplayName,EmployeeNumber,Mail,Department -ErrorAction SilentlyContinue
        } else {
            Get-ADUser -Identity $id -Properties SamAccountName,DisplayName,EmployeeNumber,Mail,Department -ErrorAction SilentlyContinue
        }
        $users[$id] = $u
    }

    # Output header
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
    Write-Host (('=' * $width)) -ForegroundColor Gray

    $added=0; $already=0; $failed=0
    foreach ($id in $Ids) {
        $u = $users[$id]
        if (-not $u) {
            Write-Host ($fmtRow -f '✗ Not found','N/A','N/A','N/A','N/A') -ForegroundColor Yellow
            $failed++ ; continue
        }
        $dn = $u.DisplayName  -or 'N/A'
        $en = $u.EmployeeNumber -or 'N/A'
        $em = $u.Mail           -or 'N/A'
        $dp = $u.Department     -or 'N/A'
        if ($existing -contains $u.SamAccountName) {
            Write-Host ($fmtRow -f '⚠ Already',$dn,$en,$em,$dp) -ForegroundColor Yellow
            $already++
        } else {
            try {
                Add-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false
                Write-Host ($fmtRow -f '✓ Added',$dn,$en,$em,$dp) -ForegroundColor Green
                $added++
            } catch {
                Write-Host ($fmtRow -f '✗ Failed',$dn,$en,$em,$dp) -ForegroundColor Yellow
                $failed++
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:   $added"    -ForegroundColor Green
    Write-Host "Already: $already"  -ForegroundColor Yellow
    Write-Host "Failed:  $failed"   -ForegroundColor Yellow
}

function Remove-Members {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]   $GroupName,
        [Parameter(Mandatory)] [string[]] $Ids
    )
    Write-Host "`nRemoving from '$GroupName':" -ForegroundColor Cyan
    # Track existing members
    $existing = Get-ADGroupMember -Identity $GroupName | Select-Object -ExpandProperty SamAccountName

    # Batch-fetch users
    $users = @{}
    foreach ($id in $Ids) {
        $u = if ($id -match '@') {
            Get-ADUser -Filter "Mail -eq '$id'" -Properties SamAccountName,DisplayName,EmployeeNumber,Mail,Department -ErrorAction SilentlyContinue
        } else {
            Get-ADUser -Identity $id -Properties SamAccountName,DisplayName,EmployeeNumber,Mail,Department -ErrorAction SilentlyContinue
        }
        $users[$id] = $u
    }

    # Output header
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeNumber','Email','Department') -ForegroundColor Gray
    Write-Host (('=' * $width)) -ForegroundColor Gray

    $removed=0; $notMember=0; $failed=0
    foreach ($id in $Ids) {
        $u = $users[$id]
        if (-not $u) {
            Write-Host ($fmtRow -f '✗ Not found','N/A','N/A','N/A','N/A') -ForegroundColor Yellow
            $failed++ ; continue
        }
        $dn = $u.DisplayName  -or 'N/A'
        $en = $u.EmployeeNumber -or 'N/A'
        $em = $u.Mail           -or 'N/A'
        $dp = $u.Department     -or 'N/A'
        if (-not ($existing -contains $u.SamAccountName)) {
            Write-Host ($fmtRow -f '⚠ Not member',$dn,$en,$em,$dp) -ForegroundColor Yellow
            $notMember++
        } else {
            try {
                Remove-ADGroupMember -Identity $GroupName -Members $u.DistinguishedName -Confirm:$false
                Write-Host ($fmtRow -f '✓ Removed',$dn,$en,$em,$dp) -ForegroundColor Green
                $removed++
            } catch {
                Write-Host ($fmtRow -f '✗ Failed',$dn,$en,$em,$dp) -ForegroundColor Yellow
                $failed++
            }
        }
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed:    $removed"    -ForegroundColor Green
    Write-Host "NotMember:  $notMember"  -ForegroundColor Yellow
    Write-Host "Failed:     $failed"     -ForegroundColor Yellow
}

# --- Main Interactive Flow ---
do {
    $group = Read-Host "`nEnter the AD group name"
    try { Get-ADGroup -Identity $group | Out-Null; $valid = $true } catch {
        Write-Host "Group '$group' not found. Try again." -ForegroundColor Yellow; $valid = $false
    }
} until ($valid)

do {
    Write-Host "`nSelect action: 1) Show  2) Add  3) Remove" -ForegroundColor Cyan
    $choice = Read-Host "Enter choice (1-3)"
} until ($choice -in '1','2','3')

switch ($choice) {
    '1' {
        $input = Read-Host "Enter search terms (space-separated), or * for all"
        $terms = $input -split '\s+' | Where-Object { $_ }
        Show-Members   -GroupName $group -Terms $terms
    }
    '2' {
        $ids = (Read-Host "Enter identifiers to add, space-separated").Split() | Where-Object { $_ }
        Add-Members    -GroupName $group -Ids $ids
    }
    '3' {
        $ids = (Read-Host "Enter identifiers to remove, space-separated").Split() | Where-Object { $_ }
        Remove-Members -GroupName $group -Ids $ids
    }
}

Write-Host "`nOperation completed." -ForegroundColor Green
