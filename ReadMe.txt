<#
.SYNOPSIS
  Interactive AD‑group management by email address.

.DESCRIPTION
  Prompts for:
    1) AD group name
    2) Action: show | add | remove
    3) (if add/remove) one or more emails
  Then confirms and performs the operation,
  printing per‑user status in color and a summary.

.NOTES
  Requires the ActiveDirectory module and run as Administrator.
#>

# Ensure the AD module is loaded
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "The ActiveDirectory module is not available. Install RSAT-AD-PowerShell and rerun."
    exit 1
}
Import-Module ActiveDirectory

# 1. Get the group name
$group = Read-Host "Enter the AD group name"

# 2. Choose action
Write-Host ""
Write-Host "Select an action:" 
Write-Host "  1) Show members"
Write-Host "  2) Add member(s)"
Write-Host "  3) Remove member(s)"
$action = Read-Host "Enter 1, 2, or 3"

# Show members and exit
if ($action -eq '1') {
    Write-Host "`nMembers of '$group':" -ForegroundColor Cyan
    Get-ADGroupMember -Identity $group -Recursive |
      Get-ADUser -Properties Mail |
      Select-Object Name, SamAccountName, @{Name='Email';Expression={$_.Mail}} |
      Format-Table -AutoSize
    exit 0
}

# 3. For add/remove, get email list
$verb = if ($action -eq '2') { 'add to' } elseif ($action -eq '3') { 'remove from' } else { Write-Error "Invalid choice"; exit 1 }
$emailsInput = Read-Host "`nEnter one or more email addresses (separate with spaces; quotes are OK)"

# Normalize input into an array of clean emails
$emails = $emailsInput -split '\s+' |
          ForEach-Object { $_.Trim("'""") } |
          Where-Object { $_ -ne '' }

if (-not $emails) {
    Write-Error "No valid email addresses provided. Exiting."
    exit 1
}

# 4. Confirmation prompt
Write-Host "`nWARNING: You are about to $verb group '$group' for these emails:`n" -ForegroundColor Yellow
$emails | ForEach-Object { Write-Host "  • $_" }
$confirm = Read-Host "`nType Y to confirm, or any other key to cancel"
if ($confirm -notmatch '^[Yy]$') {
    Write-Host "Operation cancelled by user." -ForegroundColor DarkCyan
    exit 0
}

# 5. Perform add/remove with per‑user feedback
$success = @()
$failure = @()

foreach ($email in $emails) {
    # Look up the user by Mail
    $user = Get-ADUser -Filter "Mail -eq '$email'" -Properties Mail -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "✗ User not found: $email" -ForegroundColor DarkYellow
        $failure += $email
        continue
    }

    try {
        if ($action -eq '2') {
            Add-ADGroupMember -Identity $group -Members $user.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-Host "✓ Added: $($user.SamAccountName) <$email>" -ForegroundColor Green
        } else {
            Remove-ADGroupMember -Identity $group -Members $user.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-Host "✓ Removed: $($user.SamAccountName) <$email>" -ForegroundColor Green
        }
        $success += $email
    }
    catch {
        Write-Host "✗ Failed: $($user.SamAccountName) <$email> — $_" -ForegroundColor DarkYellow
        $failure += $email
    }
}

# Summary
Write-Host "`n===== Summary =====" -ForegroundColor Cyan
Write-Host "Successful: $($success.Count)" -ForegroundColor Green
Write-Host "Failed:     $($failure.Count)" -ForegroundColor DarkYellow
if ($failure.Count -gt 0) {
    Write-Host "`nFailures:" -ForegroundColor DarkYellow
    $failure | ForEach-Object { Write-Host "  • $_" -ForegroundColor DarkYellow }
}

exit 0