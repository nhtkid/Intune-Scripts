<#
.SYNOPSIS
  Interactive AD-group management by email address or SamAccountName.

.DESCRIPTION
  Prompts for:
    • AD group name (validated)
    • Action: Show Members, Add Members, Remove Members

  • Show Members: accepts `*` (all members) or a list of emails/usernames  
  • Add/Remove: accepts a list of emails/usernames (no wildcard)

  Provides color-coded output and a summary.

.NOTES
  - Requires ActiveDirectory module
  - Run as Administrator
#>

# --- Module Check ---
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Error "ActiveDirectory module not found. Install RSAT-AD-PowerShell and run as Administrator."
    exit 1
}

# --- Helper to resolve a user by email or SamAccountName ---
function Get-ADUserByIdentifier {
    param([string]$Identifier)

    if ($Identifier -match '@') {
        return Get-ADUser -Filter "Mail -eq '$Identifier'" -Properties Mail -ErrorAction SilentlyContinue
    }
    else {
        return Get-ADUser -Identity $Identifier -Properties Mail -ErrorAction SilentlyContinue
    }
}

# --- Show-Members ---
function Show-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers  # '*' or specific emails/usernames
    )

    $showAll   = $Identifiers -contains '*'
    $found     = @(); $notFound = @(); $notInGroup = @()
    # Cache entire group membership
    $groupMembers = Get-ADGroupMember -Identity $GroupName -Recursive |
                    Get-ADUser -Properties Mail |
                    Select Name, SamAccountName, @{Name='Email';Expression={$_.Mail}}

    if ($showAll) {
        Write-Host "`nAll members of '$GroupName':" -ForegroundColor Cyan
        $groupMembers | Format-Table -AutoSize
        Write-Host "`nTotal members: $($groupMembers.Count)" -ForegroundColor Green
        return
    }

    Write-Host "`nChecking specified identifiers..." -ForegroundColor Cyan
    foreach ($id in $Identifiers) {
        $user = Get-ADUserByIdentifier $id
        if (-not $user) {
            Write-Host "✗ Not found: $id" -ForegroundColor Yellow
            $notFound += $id; continue
        }

        if ($groupMembers.SamAccountName -contains $user.SamAccountName) {
            Write-Host "✓ In group: $($user.SamAccountName) <$($user.Mail)>" -ForegroundColor Green
            $found += $id
        }
        else {
            Write-Host "⚠ Not in group: $($user.SamAccountName) <$($user.Mail)>" -ForegroundColor Yellow
            $notInGroup += $id
        }
    }

    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "In Group:     $($found.Count)"     -ForegroundColor Green
    Write-Host "Not in Group: $($notInGroup.Count)" -ForegroundColor Yellow
    Write-Host "Not Found:    $($notFound.Count)"  -ForegroundColor Yellow
}

# --- Add-Members ---
function Add-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )

    Write-Host "`nAdding members to '$GroupName'..." -ForegroundColor Cyan
    # Cache current group membership for fast checks
    $groupMembers = Get-ADGroupMember -Identity $GroupName -Recursive | Select-Object -ExpandProperty SamAccountName

    $added         = @(); $alreadyMember = @(); $failed = @()

    foreach ($id in $Identifiers) {
        $user = Get-ADUserByIdentifier $id
        if (-not $user) {
            Write-Host "✗ Not found: $id" -ForegroundColor Yellow
            $failed += $id; continue
        }

        if ($groupMembers -contains $user.SamAccountName) {
            Write-Host "⚠ Already member: $($user.SamAccountName)" -ForegroundColor Yellow
            $alreadyMember += $id
        }
        else {
            try {
                Add-ADGroupMember -Identity $GroupName -Members $user.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "✓ Added: $($user.SamAccountName) <$($user.Mail)>" -ForegroundColor Green
                $added += $id
            }
            catch {
                Write-Host "✗ Failed adding $id — $($_.Exception.Message)" -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:          $($added.Count)"         -ForegroundColor Green
    Write-Host "Already Member: $($alreadyMember.Count)" -ForegroundColor Yellow
    Write-Host "Failed:         $($failed.Count)"        -ForegroundColor Yellow
}

# --- Remove-Members ---
function Remove-Members {
    param(
        [string]   $GroupName,
        [string[]] $Identifiers
    )

    Write-Host "`nRemoving members from '$GroupName'..." -ForegroundColor Cyan
    # Cache current group membership for fast checks
    $groupMembers = Get-ADGroupMember -Identity $GroupName -Recursive | Select-Object -ExpandProperty SamAccountName

    $removed    = @(); $notMember = @(); $failed = @()

    foreach ($id in $Identifiers) {
        $user = Get-ADUserByIdentifier $id
        if (-not $user) {
            Write-Host "✗ Not found: $id" -ForegroundColor Yellow
            $failed += $id; continue
        }

        if (-not ($groupMembers -contains $user.SamAccountName)) {
            Write-Host "⚠ Not a member: $($user.SamAccountName)" -ForegroundColor Yellow
            $notMember += $id
        }
        else {
            try {
                Remove-ADGroupMember -Identity $GroupName -Members $user.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "✓ Removed: $($user.SamAccountName) <$($user.Mail)>" -ForegroundColor Green
                $removed += $id
            }
            catch {
                Write-Host "✗ Failed removing $id — $($_.Exception.Message)" -ForegroundColor Yellow
                $failed += $id
            }
        }
    }

    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed:    $($removed.Count)"    -ForegroundColor Green
    Write-Host "Not Member: $($notMember.Count)" -ForegroundColor Yellow
    Write-Host "Failed:     $($failed.Count)"    -ForegroundColor Yellow
}

# --- Main Prompt Flow ---

# 1) Prompt & validate group name
do {
    $group = Read-Host "`nEnter the AD group name"
    try {
        Get-ADGroup -Identity $group -ErrorAction Stop | Out-Null
        $valid = $true
    }
    catch {
        Write-Host "Group '$group' not found. Please try again." -ForegroundColor Yellow
        $valid = $false
    }
} until ($valid)

# 2) Choose action
Write-Host "`nSelect an action:" -ForegroundColor Cyan
Write-Host "  1) Show Members (enter * for all, or specific emails/usernames)"
Write-Host "  2) Add Members"
Write-Host "  3) Remove Members"
$choice = Read-Host "`nEnter choice (1-3)"

# 3) Dispatch
switch ($choice) {
    '1' {
        $input = Read-Host "Enter identifiers (emails/usernames) separated by spaces, or *"
        $items = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Show-Members -GroupName $group -Identifiers $items
    }
    '2' {
        $input = Read-Host "Enter identifiers to add, separated by spaces"
        $items = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Add-Members -GroupName $group -Identifiers $items
    }
    '3' {
        $input = Read-Host "Enter identifiers to remove, separated by spaces"
        $items = $input -split '\s+' | Where-Object { $_.Trim() -ne '' }
        Remove-Members -GroupName $group -Identifiers $items
    }
    default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`nOperation completed." -ForegroundColor Green
