<#
.SYNOPSIS
  Interactive Entra ID (Azure AD) group management by email/UPN or device name on PowerShell 5.1,
  with CSV import support for bulk Add/Remove (with column heading EmailAddress for users or DeviceName for devices).

.NOTES
  • Requires AzureAD module (Install-Module AzureAD)
  • Will prompt for Connect-AzureAD if not already connected
#>

param()  # prevent output when dot-sourced

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
    $groups = Get-AzureADGroup -Filter $filter
    if ($groups.Count -eq 1) { return $groups[0] }
    elseif ($groups.Count -gt 1) {
        Write-Host "Multiple groups named '$Name':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $groups.Count; $i++) {
            $g = $groups[$i]
            Write-Host "[$($i+1)] $($g.DisplayName) (Id: $($g.ObjectId))"
        }
        $sel = Read-Host "Enter number"
        if ($sel -as [int] -and $sel -ge 1 -and $sel -le $groups.Count) {
            return $groups[$sel - 1]
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
        if ($u) { return $u }
        return Get-AzureADUser -Filter "mail eq '$Id'" -ErrorAction SilentlyContinue
    }
    return Get-AzureADUser -Filter "userPrincipalName eq '$Id'" -ErrorAction SilentlyContinue
}

function Get-DeviceByName {
    param([string]$Name)
    $devices = Get-AzureADDevice -All $true | Where-Object { $_.DisplayName -eq $Name }
    if ($devices.Count -eq 1) { return $devices[0] }
    elseif ($devices.Count -gt 1) {
        Write-Host "Multiple devices named '$Name':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $devices.Count; $i++) {
            $d = $devices[$i]
            Write-Host "[$($i+1)] $($d.DisplayName) (Id: $($d.ObjectId))"
        }
        $sel = Read-Host "Enter number"
        if ($sel -as [int] -and $sel -ge 1 -and $sel -le $devices.Count) {
            return $devices[$sel - 1]
        }
    }
    return $null
}

# Formatting
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

# --- Core Operations ---
function Show-Members {
    param(
        [string]   $GroupId,
        [string[]] $Terms
    )

    Write-Host "Loading members..." -ForegroundColor Cyan
    $members = Get-AzureADGroupMember -ObjectId $GroupId -All $true

    $users = $members | Where-Object { $_.ObjectType -eq 'User' } | ForEach-Object { Get-AzureADUser -ObjectId $_.ObjectId }
    $devices = $members | Where-Object { $_.ObjectType -eq 'Device' } | ForEach-Object { Get-AzureADDevice -ObjectId $_.ObjectId }

    $showAll = $Terms -contains '*'
    if ($showAll) {
        $ps   = Read-Host "Page size (or Enter for no paging)"
        $size = 0
        if ($ps -and ($ps -as [int]) -gt 0) { $size = [int]$ps }

        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
        Write-Host ("=" * 140)
        $count = 0
        foreach ($u in $users) {
            if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
            if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
            if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
            if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }

            Write-Host ($fmtData -f $dn,$eid,$em,$dp)
            $count++
            if ($size -gt 0 -and ($count % $size) -eq 0) {
                Write-Host ("-" * 140)
            }
        }
        foreach ($d in $devices) {
            $dn = $d.DisplayName
            Write-Host ($fmtData -f $dn,'N/A','N/A','N/A')
            $count++
            if ($size -gt 0 -and ($count % $size) -eq 0) {
                Write-Host ("-" * 140)
            }
        }
        Write-Host "Total: $count" -ForegroundColor Green
        return
    }

    Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)
    $found = 0; $no = @()
    foreach ($term in $Terms) {
        $pat = $term.ToLower()
        $matches = @()

        $matches += $users | Where-Object {
            ($_.DisplayName -and $_.DisplayName.ToLower().Contains($pat)) -or
            ($_.EmployeeId  -and $_.EmployeeId.ToLower().Contains($pat)) -or
            ($_.Mail        -and $_.Mail.ToLower().Contains($pat))
        }

        $matches += $devices | Where-Object {
            $_.DisplayName -and $_.DisplayName.ToLower().Contains($pat)
        }

        if ($matches) {
            foreach ($m in $matches) {
                if ($m.ObjectType -eq 'User') {
                    if ($m.DisplayName) { $dn = $m.DisplayName } else { $dn = 'N/A' }
                    if ($m.EmployeeId)  { $eid = $m.EmployeeId }  else { $eid = 'N/A' }
                    if ($m.Mail)        { $em = $m.Mail }        else { $em = 'N/A' }
                    if ($m.Department)  { $dp = $m.Department }  else { $dp = 'N/A' }
                } else {
                    $dn = $m.DisplayName
                    $eid = $em = $dp = 'N/A'
                }
                Write-Host ($fmtData -f $dn,$eid,$em,$dp)
                $found++
            }
        } else {
            Write-Host ($fmtStatus -f "✗ No match: $term") -ForegroundColor Yellow
            $no += $term
        }
    }
    Write-Host "Matched: $found" -ForegroundColor Green
    if ($no) { Write-Host "No matches: $($no -join ', ')" -ForegroundColor Yellow }
}

function Add-Members {
    param(
        [string]   $GroupId,
        [string[]] $Ids
    )
    Write-Host "Adding..." -ForegroundColor Cyan

    $cache = @{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true |
      ForEach-Object {
          $obj = $_
          $cache[$obj.ObjectId] = $true
      }

    $added = @(); $already = @(); $failed = @()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)

    foreach ($id in $Ids) {
        $u = Get-UserById $id
        if ($u) {
            $objId = $u.ObjectId
            if ($cache.ContainsKey($objId)) {
                Write-Host ($fmtStatus -f "⚠ Already:      ") -NoNewline
                Write-Host ($fmtData -f $u.DisplayName,$u.EmployeeId,$u.Mail,$u.Department) -ForegroundColor Yellow
                $already += $id; continue
            }
            try {
                Add-AzureADGroupMember -ObjectId $GroupId -RefObjectId $objId -ErrorAction Stop
                Write-Host ($fmtStatus -f "✓ Added:        ") -NoNewline
                Write-Host ($fmtData -f $u.DisplayName,$u.EmployeeId,$u.Mail,$u.Department) -ForegroundColor Green
                $added += $id
                $cache[$objId] = $true
            }
            catch {
                Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
                Write-Host ($fmtData -f $u.DisplayName,$u.EmployeeId,$u.Mail,$
::contentReference[oaicite:8]{index=8}


<#
.SYNOPSIS
  Interactive Entra ID (Azure AD) group management by email/UPN on PowerShell 5.1,
  with CSV import support for bulk Add/Remove (with column headding EmailAddress).

.NOTES
  • Requires AzureAD module (Install-Module AzureAD)
  • Will prompt for Connect-AzureAD if not already connected
#>

param()  # prevent output when dot-sourced

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
    $groups = Get-AzureADGroup -Filter $filter
    if ($groups.Count -eq 1) { return $groups[0] }
    elseif ($groups.Count -gt 1) {
        Write-Host "Multiple groups named '$Name':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $groups.Count; $i++) {
            $g = $groups[$i]
            Write-Host "[$($i+1)] $($g.DisplayName) (Id: $($g.ObjectId))"
        }
        $sel = Read-Host "Enter number"
        if ($sel -as [int] -and $sel -ge 1 -and $sel -le $groups.Count) {
            return $groups[$sel - 1]
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
        if ($u) { return $u }
        return Get-AzureADUser -Filter "mail eq '$Id'" -ErrorAction SilentlyContinue
    }
    return Get-AzureADUser -Filter "userPrincipalName eq '$Id'" -ErrorAction SilentlyContinue
}

# Formatting
$fmtStatus = "{0,-15}"
$fmtData   = "{0,-45} {1,-15} {2,-50} {3,-20}"
$fmtRow    = $fmtStatus + " " + $fmtData

# --- Core Operations ---
function Show-Members {
    param(
        [string]   $GroupId,
        [string[]] $Terms
    )

    Write-Host "Loading members..." -ForegroundColor Cyan
    $members = Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User'
    $users = $members | ForEach-Object { Get-AzureADUser -ObjectId $_.ObjectId }

    $showAll = $Terms -contains '*'
    if ($showAll) {
        $ps   = Read-Host "Page size (or Enter for no paging)"
        $size = 0
        if ($ps -and ($ps -as [int]) -gt 0) { $size = [int]$ps }

        Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
        Write-Host ("=" * 140)
        $count = 0
        foreach ($u in $users) {
            if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
            if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
            if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
            if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }

            Write-Host ($fmtData -f $dn,$eid,$em,$dp)
            $count++
            if ($size -gt 0 -and ($count % $size) -eq 0) {
                Write-Host ("-" * 140)
            }
        }
        Write-Host "Total: $count" -ForegroundColor Green
        return
    }

    Write-Host ($fmtData -f 'DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)
    $found = 0; $no = @()
    foreach ($term in $Terms) {
        $pat = $term.ToLower()
        $matches = $users | Where-Object {
            ($_.DisplayName -and $_.DisplayName.ToLower().Contains($pat)) -or
            ($_.EmployeeId  -and $_.EmployeeId.ToLower().Contains($pat)) -or
            ($_.Mail        -and $_.Mail.ToLower().Contains($pat))
        }
        if ($matches) {
            foreach ($u in $matches) {
                if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
                if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
                if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
                if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }

                Write-Host ($fmtData -f $dn,$eid,$em,$dp)
                $found++
            }
        } else {
            Write-Host ($fmtStatus -f "✗ No match: $term") -ForegroundColor Yellow
            $no += $term
        }
    }
    Write-Host "Matched: $found" -ForegroundColor Green
    if ($no) { Write-Host "No matches: $($no -join ', ')" -ForegroundColor Yellow }
}

function Add-Members {
    param(
        [string]   $GroupId,
        [string[]] $Ids
    )
    Write-Host "Adding..." -ForegroundColor Cyan

    $cache = @{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User' |
      ForEach-Object {
          $u = Get-AzureADUser -ObjectId $_.ObjectId
          if ($u.UserPrincipalName) {
              $cache[$u.UserPrincipalName.ToLower()] = $u.ObjectId
          }
      }

    $added = @(); $already = @(); $failed = @()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)

    foreach ($id in $Ids) {
        $u = Get-UserById $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }

        if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
        if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
        if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
        if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }
        $upn = $u.UserPrincipalName.ToLower()

        if ($cache.ContainsKey($upn)) {
            Write-Host ($fmtStatus -f "⚠ Already:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $already += $id; continue
        }

        try {
            Add-AzureADGroupMember -ObjectId $GroupId -RefObjectId $u.ObjectId -ErrorAction Stop
            Write-Host ($fmtStatus -f "✓ Added:        ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
            $added += $id
            $cache[$upn] = $u.ObjectId
        }
        catch {
            Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $failed += $id
        }
    }

    Write-Host "Added: $($added.Count)  Already: $($already.Count)  Failed: $($failed.Count)" -ForegroundColor Cyan
}

function Remove-Members {
    param(
        [string]   $GroupId,
        [string[]] $Ids
    )
    Write-Host "Removing..." -ForegroundColor Cyan

    $cache = @{}
    Get-AzureADGroupMember -ObjectId $GroupId -All $true | Where-Object ObjectType -eq 'User' |
      ForEach-Object {
          $u = Get-AzureADUser -ObjectId $_.ObjectId
          if ($u.UserPrincipalName) {
              $cache[$u.UserPrincipalName.ToLower()] = $u.ObjectId
          }
      }

    $removed = @(); $notmem = @(); $failed = @()
    Write-Host ($fmtRow -f 'Status','DisplayName','EmployeeId','Mail','Department')
    Write-Host ("=" * 140)

    foreach ($id in $Ids) {
        $u = Get-UserById $id
        if (-not $u) {
            Write-Host ($fmtStatus -f "✗ Not found: $id") -ForegroundColor Yellow
            $failed += $id; continue
        }

        if ($u.DisplayName) { $dn = $u.DisplayName } else { $dn = 'N/A' }
        if ($u.EmployeeId)  { $eid = $u.EmployeeId }  else { $eid = 'N/A' }
        if ($u.Mail)        { $em = $u.Mail }        else { $em = 'N/A' }
        if ($u.Department)  { $dp = $u.Department }  else { $dp = 'N/A' }
        $upn = $u.UserPrincipalName.ToLower()

        if (-not $cache.ContainsKey($upn)) {
            Write-Host ($fmtStatus -f "⚠ Not mem:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $notmem += $id; continue
        }

        try {
            Remove-AzureADGroupMember -ObjectId $GroupId -MemberId $cache[$upn] -ErrorAction Stop
            Write-Host ($fmtStatus -f "✓ Removed:      ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Green
            $removed += $id
            $cache.Remove($upn) | Out-Null
        }
        catch {
            Write-Host ($fmtStatus -f "✗ Failed:       ") -NoNewline
            Write-Host ($fmtData -f $dn,$eid,$em,$dp) -ForegroundColor Yellow
            $failed += $id
        }
    }

    Write-Host "Removed: $($removed.Count)  Not mem: $($notmem.Count)  Failed: $($failed.Count)" -ForegroundColor Cyan
}

# --- CSV/Manual Input Helper ---
function Get-InputIds {
    param([string]$msg)

    while ($true) {
        $v = Read-Host $msg
        if (-not $v) { Write-Host "Input required." -ForegroundColor Yellow; continue }

        $path = $v.Trim().Trim('"')
        try {
            $rp = Resolve-Path -Path $path -ErrorAction Stop
            $path = $rp.ProviderPath
        } catch {
            $rp = $null
        }

        if ($rp -and (Test-Path $path) -and ([IO.Path]::GetExtension($path) -ieq '.csv')) {
            try { $data = Import-Csv -Path $path -ErrorAction Stop }
            catch { Write-Host "CSV import failed." -ForegroundColor Red; continue }

            if ($data.Count -and $data[0].PSObject.Properties.Name -contains 'EmailAddress') {
                $ids = $data | ForEach-Object { $_.EmailAddress.Trim() } | Where-Object { $_ }
                if ($ids.Count) { return $ids }
            }
            Write-Host "CSV must have 'EmailAddress' column with data." -ForegroundColor Yellow
        } else {
            $ids = $v -split '\s+' | Where-Object { $_.Trim() }
            if ($ids.Count) { return $ids }
        }
    }
}

# --- Main ---
function Main {
    Ensure-Connection

    do {
        $name = Read-Host "Azure AD group DisplayName"
        $grp  = Get-GroupByName $name
    } until ($grp)
    $gid = $grp.ObjectId

    do {
        Write-Host "1) Show  2) Add  3) Remove"
        $choice = Read-Host "Choose (1-3)"
    } until ($choice -in '1','2','3')

    switch ($choice) {
        '1' {
            $t = Read-Host "Terms (space-separated) or *"
            Show-Members -GroupId $gid -Terms ($t -split '\s+' | Where-Object { $_ })
        }
        '2' {
            $ids = Get-InputIds "Provide emails/UPNs or CSV path"
            Add-Members    -GroupId $gid -Ids $ids
        }
        '3' {
            $ids = Get-InputIds "Provide emails/UPNs or CSV path"
            Remove-Members -GroupId $gid -Ids $ids
        }
    }

    Write-Host "Done." -ForegroundColor Green
}

# Run Main if invoked as a script
if ($PSCommandPath) {
    Main
}
