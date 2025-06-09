<#
.SYNOPSIS
  Interactive AD‑group management by email address.

.DESCRIPTION
  Prompts for:
    • AD group name (validated)
    • Action: Show Members, Add member(s), Remove member(s)
  Show Members will accept:
    • * to display all members
    • one or more email addresses
  Add/Remove only accept email lists.
  Prints colored per‑user results and a summary.

.NOTES
  Requires the ActiveDirectory module and run as Administrator.
#>

# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "The ActiveDirectory module is not available. Install RSAT-AD-PowerShell and rerun."
    exit 1
}
Import-Module ActiveDirectory

function Show-Members {
    param(
        [string]$GroupName,
        [string[]]$Emails  # '*' or specific emails
    )
    $all = $Emails -contains '*'
    $found = @()
    $notFound = @()

    if ($all) {
        # Fetch every member
        $users = Get-ADGroupMember -Identity $GroupName -Recursive |
                 Get-ADUser -Properties Mail |
                 Select-Object Name, SamAccountName, @{Name='Email';Expression={$_.Mail}}
        $users | Format-Table -AutoSize
        $found = $users | ForEach-Object { $_.Email }
    }
    else {
        foreach ($email in $Emails) {
            $user = Get-ADUser -Filter "Mail -eq '$email'" -Properties Mail -ErrorAction SilentlyContinue
            if ($user) {
                $found += $user.Mail
                [PSCustomObject]@{
                    Name           = $user.Name
                    SamAccountName = $user.SamAccountName
                    Email          = $user.Mail
                }
            }
            else {
                Write-Host "User not found: $email" -ForegroundColor Yellow
                $notFound += $email
            }
        }
        if ($found) {
            $found | ForEach-Object {
                $u = Get-ADUser -Filter "Mail -eq '$_'" -Properties Mail
                [PSCustomObject]@{
                    Name           = $u.Name
                    SamAccountName = $u.SamAccountName
                    Email          = $u.Mail
                }
            } | Format-Table -AutoSize
        }
    }

    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    if ($all) {
        Write-Host "Total members displayed: $($found.Count)" -ForegroundColor Green
    }
    else {
        Write-Host "Found:    $($found.Count)"    -ForegroundColor Green
        Write-Host "NotFound: $($notFound.Count)" -ForegroundColor Yellow
    }
}

function Add-Members {
    param(
        [string]$GroupName,
        [string[]]$Emails
    )
    $success = @(); $failure = @()
    foreach ($email in $Emails) {
        $user = Get-ADUser -Filter "Mail -eq '$email'" -Properties Mail -ErrorAction SilentlyContinue
        if (-not $user) {
            Write-Host "✗ User not found: $email" -ForegroundColor Yellow
            $failure += $email; continue
        }
        try {
            Add-ADGroupMember -Identity $GroupName -Members $user.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-Host "✓ Added: $($user.SamAccountName) <$email>" -ForegroundColor Green
            $success += $email
        }
        catch {
            Write-Host "✗ Failed adding $email — $_" -ForegroundColor Yellow
            $failure += $email
        }
    }
    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Added:   $($success.Count)" -ForegroundColor Green
    Write-Host "Failed:  $($failure.Count)" -ForegroundColor Yellow
    if ($failure) { $failure | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow } }
}

function Remove-Members {
    param(
        [string]$GroupName,
        [string[]]$Emails
    )
    $success = @(); $failure = @()
    foreach ($email in $Emails) {
        $user = Get-ADUser -Filter "Mail -eq '$email'" -Properties Mail -ErrorAction SilentlyContinue
        if (-not $user) {
            Write-Host "✗ User not found: $email" -ForegroundColor Yellow
            $failure += $email; continue
        }
        try {
            Remove-ADGroupMember -Identity $GroupName -Members $user.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-Host "✓ Removed: $($user.SamAccountName) <$email>" -ForegroundColor Green
            $success += $email
        }
        catch {
            Write-Host "✗ Failed removing $email — $_" -ForegroundColor Yellow
            $failure += $email
        }
    }
    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Removed: $($success.Count)" -ForegroundColor Green
    Write-Host "Failed:  $($failure.Count)" -ForegroundColor Yellow
    if ($failure) { $failure | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow } }
}


### —— Main Prompt Flow —— ###

# Group‑name validation loop
do {
    $group = Read-Host "Enter the AD group name"
    $exists = Get-ADGroup -Identity $group -ErrorAction SilentlyContinue
    if (-not $exists) {
        Write-Host "Group '$group' not found. Please enter a valid AD group name." -ForegroundColor Yellow
    }
} until ($exists)

Write-Host ""
Write-Host "Select an action:"
Write-Host "  1) Show Members (Type * to show all members)"
Write-Host "  2) Add member(s)"
Write-Host "  3) Remove member(s)"
$choice = Read-Host "Enter 1, 2, or 3"

switch ($choice) {
    '1' {
        $input = Read-Host "Enter email(s) separated by spaces, or *"
        $items = $input -split '\s+' | ForEach-Object { $_.Trim("'""") } | Where-Object { $_ -ne '' }
        Show-Members -GroupName $group -Emails $items
    }
    '2' {
        $input = Read-Host "Enter email(s) to add, separated by spaces"
        $items = $input -split '\s+' | ForEach-Object { $_.Trim("'""") } | Where-Object { $_ -ne '' }
        Add-Members   -GroupName $group -Emails $items
    }
    '3' {
        $input = Read-Host "Enter email(s) to remove, separated by spaces"
        $items = $input -split '\s+' | ForEach-Object { $_.Trim("'""") } | Where-Object { $_ -ne '' }
        Remove-Members -GroupName $group -Emails $items
    }
    default {
        Write-Error "Invalid selection. Exiting."
    }
}

exit 0