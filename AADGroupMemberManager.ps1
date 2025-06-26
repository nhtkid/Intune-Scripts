<#
.SYNOPSIS
  Interactive Entra ID (Azure AD) group management by email/UPN on PowerShell 5.1,
  with CSV import support for bulk Add/Remove.

.NOTES
  • Requires AzureAD module (Install-Module AzureAD)
  • Will prompt for Connect-AzureAD if not already connected
#>

# Prevent output when dot-sourced
param()

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
    $g = Get-AzureADGroup -Filter $filter
    if ($g.Count -eq 1) { return $g }
    elseif ($g.Count -gt 1) {
        Write-Host "Multiple groups named '$Name':" -ForegroundColor Yellow
        $i=1; foreach ($grp in $g) {
            Write-Host "[$i] $($grp.DisplayName) (Id: $($grp.ObjectId))"
            $i++
        }
        $sel = Read-Host "Enter number"
        if ($sel -as [int] -and $sel -ge 1 -and $sel -le $g.Count) {
            return $g[$sel-1]
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
        return $u ? $u : (Get-AzureADUser -Filter "mail eq '$Id'" -ErrorAction SilentlyContinue)
    }
    return Get-AzureADUser -Filter "userPrincipalName eq '$Id'" -ErrorAction SilentlyContinue
}

# Formatting
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

# --- Core Operations ---
function Show-Members {
    param($GroupId, [string[]]$Terms)
    Write-Host "Loading members..." -ForegroundColor Cyan
    $all = Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User'
    $users = $all | ForEach-Object { Get-AzureADUser -ObjectId $_.ObjectId }
    $showAll = $Terms -contains '*'
    if ($showAll) {
        $ps = Read-Host "Page size (or Enter for no paging)"
        $size = ($ps -as [int] -gt 0) ? [int]$ps : 0
        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
        Write-Host ("="*140)
        $c=0
        foreach ($u in $users) {
            $dn = $u.DisplayName   ; if (-not $dn) { $dn='N/A' }
            $eid= $u.EmployeeId    ; if (-not $eid){ $eid='N/A'}
            $em = $u.Mail          ; if (-not $em) { $em='N/A' }
            $dp = $u.Department    ; if (-not $dp){ $dp='N/A'}
            Write-Host ($fmtData -f $dn,$eid,$em,$dp)
            if ($size -gt 0 -and (++$c % $size) -eq 0) { Write-Host ("-"*140) }
        }
        Write-Host "Total: $c" -ForegroundColor Green
    } else {
        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
        Write-Host ("="*140)
        $found=0; $no=@()
        foreach ($t in $Terms) {
            $p=$t.ToLower()
            $m = $users | Where-Object {
                ($_.DisplayName -and $_.DisplayName.ToLower().Contains($p)) -or
                ($_.EmployeeId  -and $_.EmployeeId.ToLower().Contains($p)) -or
                ($_.Mail        -and $_.Mail.ToLower().Contains($p))
            }
            if ($m) {
                foreach ($u in $m) {
                    $dn=$u.DisplayName; if(-not $dn){$dn='N/A'}
                    $eid=$u.EmployeeId;if(-not $eid){$eid='N/A'}
                    $em=$u.Mail        ;if(-not $em){$em='N/A'}
                    $dp=$u.Department  ;if(-not $dp){$dp='N/A'}
                    Write-Host ($fmtData -f $dn,$eid,$em,$dp)
                    $found++
                }
            } else {
                Write-Host ($fmtStatus -f "✗ No match: $t") -ForegroundColor Yellow
                $no += $t
            }
        }
        Write-Host "Matched: $found" -ForegroundColor Green
        if ($no) { Write-Host "No matches: $($no -join ', ')" -ForegroundColor Yellow }
    }
}

function Add-Members {
    param($GroupId, [string[]]$Ids)
    Write-Host "Adding..." -ForegroundColor Cyan
    $cache = @{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User' |
      ForEach-Object { $u=Get-AzureADUser -ObjectId $_.ObjectId; $cache[$u.UserPrincipalName.ToLower()]=$u.ObjectId }

    $added=@(); $already=@(); $fail=@()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("="*140)
    foreach ($id in $Ids) {
        $u=Get-UserById $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $fail+=$id; continue
        }
        $dn=$u.DisplayName; if(-not $dn){$dn='N/A'}
        $eid=$u.EmployeeId;if(-not $eid){$eid='N/A'}
        $em=$u.Mail        ;if(-not $em){$em='N/A'}
        $dp=$u.Department  ;if(-not $dp){$dp='N/A'}
        $upn=$u.UserPrincipalName.ToLower()
        if ($cache.ContainsKey($upn)) {
            Write-Host ($fmtStatus -f "⚠ Already:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $already+=$id; continue
        }
        try {
            Add-AzureADGroupMember -ObjectId $GroupId -RefObjectId $u.ObjectId -ErrorAction Stop
            Write-Host ($fmtStatus -f "✓ Added:        ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
            $added+=$id
            $cache[$upn]=$u.ObjectId
        } catch {
            Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $fail+=$id
        }
    }
    Write-Host "Added: $($added.Count)  Already: $($already.Count)  Failed: $($fail.Count)" -ForegroundColor Cyan
}

function Remove-Members {
    param($GroupId, [string[]]$Ids)
    Write-Host "Removing..." -ForegroundColor Cyan
    $cache=@{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User' |
      ForEach-Object { $u=Get-AzureADUser -ObjectId $_.ObjectId; $cache[$u.UserPrincipalName.ToLower()]=$u.ObjectId }

    $rem=@(); $not=@(); $fail=@()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("="*140)
    foreach ($id in $Ids) {
        $u=Get-UserById $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $fail+=$id; continue
        }
        $dn=$u.DisplayName; if(-not $dn){$dn='N/A'}
        $eid=$u.EmployeeId;if(-not $eid){$eid='N/A'}
        $em=$u.Mail        ;if(-not $em){$em='N/A'}
        $dp=$u.Department  ;if(-not $dp){$dp='N/A'}
        $upn=$u.UserPrincipalName.ToLower()
        if (-not $cache.ContainsKey($upn)) {
            Write-Host ($fmtStatus -f "⚠ Not mem:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $not+=$id; continue
        }
        try {
            Remove-AzureADGroupMember -ObjectId $GroupId -MemberId $cache[$upn] -ErrorAction Stop
            Write-Host ($fmtStatus -f "✓ Removed:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
            $rem+=$id
            $cache.Remove($upn) | Out-Null
        } catch {
            Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $fail+=$id
        }
    }
    Write-Host "Removed: $($rem.Count)  Not mem: $($not.Count)  Failed: $($fail.Count)" -ForegroundColor Cyan
}

# --- CSV/Manual Input Helper ---
function Get-InputIds {
    param([string]$msg)
    while ($true) {
        $v = Read-Host $msg
        if (-not $v) { Write-Host "Input required." -ForegroundColor Yellow; continue }
        $path = $v.Trim().Trim('"')
        try { $rp=Resolve-Path $path -ErrorAction Stop; $path=$rp }
        catch { $rp=$null }
        if ($rp -and (Test-Path $path) -and ([IO.Path]::GetExtension($path) -ieq '.csv')) {
            try { $data=Import-Csv $path } catch { Write-Host "CSV error." -ForegroundColor Red; continue }
            if ($data[0].PSObject.Properties.Name -contains 'EmailAddress') {
                $ids = $data | ForEach-Object { $_.EmailAddress.Trim() } | Where-Object { $_ }
                if ($ids) { return $ids }
            }
            Write-Host "CSV needs column 'EmailAddress' with values." -ForegroundColor Yellow
        } else {
            $ids = $v -split '\s+' | Where-Object { $_.Trim() }
            if ($ids) { return $ids }
        }
    }
}

# --- Main ---
function Main {
    Ensure-Connection
    do {
        $g = Read-Host "Azure AD group DisplayName"
        $grp = Get-GroupByName $g
    } until ($grp)
    $gid = $grp.ObjectId

    do {
        Write-Host "1) Show  2) Add  3) Remove"
        $c = Read-Host "Choose (1-3)"
    } until ($c -in '1','2','3')

    switch ($c) {
        '1' {
            $t=Read-Host "Terms (space-separated) or *"
            Show-Members -GroupId $gid -Terms ($t -split '\s+' | Where-Object { $_ })
        }
        '2' {
            $ids=Get-InputIds "Provide emails/UPNs or CSV path"
            Add-Members    -GroupId $gid -Ids $ids
        }
        '3' {
            $ids=Get-InputIds "Provide emails/UPNs or CSV path"
            Remove-Members -GroupId $gid -Ids $ids
        }
    }
    Write-Host "Done." -ForegroundColor Green
}

if ($PSCommandPath) { Main }
