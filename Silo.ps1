# --- ADMIN CHECK ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "       ERROR: THIS TOOL MUST BE RUN AS ADMINISTRATOR      " -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "Please right-click your shortcut and select 'Run as Administrator'."
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# --- HEADER ---
Clear-Host
$host.ui.RawUI.WindowTitle = "Evidence Silo & Recovery Tool"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         EVIDENCE SILO & RECOVERY TOOL v1.6               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Status: ADMIN VERIFIED" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Mode Selection
Write-Host "SELECT ACTION:" -ForegroundColor White
Write-Host "1. SILO  (Isolate/Blind Folder)"
Write-Host "2. RESET (Restore Standard Inheritance)"
Write-Host "3. CLEAR (Wipe All Restrictions - Local Admin Only)"
Write-Host "4. EXIT  (Close Tool)"
$mode = Read-Host -Prompt "Choice"

# 2. Input Handling
if ($mode -eq "4") { exit }
$RawInput = Read-Host -Prompt "Paste the full path of the folder"
$dir = $RawInput.Trim('"').Trim("'").Trim()

if (!(Test-Path $dir)) {
    Write-Host "`n[!] Error: Path not found: $dir" -ForegroundColor Red
    pause; return
}

# --- MODE 1: SILO ---
if ($mode -eq "1") {
    Write-Host "`nChoose Restriction Level:" -ForegroundColor White
    Write-Host "1. Full Isolation (NW, NR, NX) - [THE MORGUE]"
    Write-Host "2. No Write / No Execute (NW, NX) - [FREEZE]"
    Write-Host "3. No Write Only (NW) - [LOCK]"
    $choice = Read-Host -Prompt "Select (1-3)"

    switch ($choice) {
        "1" { $flags = "RD,WD,X";  $label = "NW,NR,NX" }
        "2" { $flags = "WD,X";     $label = "NW,NX"    }
        "3" { $flags = "WD";       $label = "NW"       }
        default { Write-Host "Invalid choice."; pause; return }
    }

    Write-Host "`n[!] STEP 1: Forcing Ownership..." -ForegroundColor Yellow
    takeown /f "$dir" /a /r /d y > $null

    Write-Host "[!] STEP 2: Wiping & Writing Clean Slate..." -ForegroundColor Yellow
    icacls "$dir" /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" /T /C > $null

    Write-Host "[!] STEP 3: Applying Restricted SID Blindfold..." -ForegroundColor Yellow
    icacls "$dir" /deny "*S-1-5-12:(OI)(CI)($flags)" /T /C > $null

    Write-Host "[!] STEP 4: Forcing Kernel Integrity Barrier..." -ForegroundColor Yellow
    icacls "$dir" /setintegritylevel "(OI)(CI)M" /T /C > $null
    icacls "$dir" /setintegritylevel "(OI)(CI)L:($label)" /T /C > $null

    # --- THE TRIPLE VERIFICATION BLOCK ---
    Write-Host "`n[?] Running Forensic Verification..." -ForegroundColor Cyan
    $Acl = Get-Acl $dir
    $IcaclsOutput = icacls "$dir"
    $SACL = $IcaclsOutput -join " "

    # Check 1: Clean Slate (Only You, System, and the Deny SID should exist)
    $UserCount = ($Acl.Access | Select-Object -ExpandProperty IdentityReference -Unique).Count
    
    # Check 2: Restricted SID Deny
    $DenyFound = $Acl.Access | Where-Object { $_.IdentityReference -like "*RESTRICTED*" -and $_.AccessControlType -eq "Deny" }

    # Check 3: Integrity Level
    $IntegrityFound = $SACL -match "Mandatory Label\\Low Mandatory Level"

    Write-Host "----------------------------------------------------------"
    # Verification 1
    if ($UserCount -le 3) { Write-Host "[OK] CHECK 1: Clean Slate (Inheritance Disabled)" -ForegroundColor Green }
    else { Write-Host "[!] CHECK 1: Warning (Found $UserCount identities)" -ForegroundColor Yellow }

    # Verification 2
    if ($DenyFound) { Write-Host "[OK] CHECK 2: Restricted SID Deny (Active)" -ForegroundColor Green } 
    else { Write-Host "[FAIL] CHECK 2: Restricted SID Deny (Not Found)" -ForegroundColor Red }

    # Verification 3
    if ($IntegrityFound) { Write-Host "[OK] CHECK 3: Kernel Integrity Barrier (Active)" -ForegroundColor Green } 
    else { Write-Host "[FAIL] CHECK 3: Kernel Integrity Barrier (Not Found)" -ForegroundColor Red }
    Write-Host "----------------------------------------------------------"
} 

# --- MODE 2: RESET ---
elseif ($mode -eq "2") {
    Write-Host "`n[!] RESTORING INHERITANCE: $dir..." -ForegroundColor Yellow
    takeown /f "$dir" /a /r /d y > $null
    icacls "$dir" /setintegritylevel "(OI)(CI)M" /T /C > $null
    icacls "$dir" /remove:d "*S-1-5-12" /T /C > $null
    icacls "$dir" /inheritance:e /reset /T /C > $null
    Write-Host "[+] SUCCESS: Standard privileges restored." -ForegroundColor Green
}

# --- MODE 3: CLEAR ---
elseif ($mode -eq "3") {
    Write-Host "`n[!] NUCLEAR CLEARING PERMISSIONS: $dir..." -ForegroundColor Yellow
    takeown /f "$dir" /a /r /d y > $null
    icacls "$dir" /setintegritylevel "(OI)(CI)M" /T /C > $null
    icacls "$dir" /inheritance:r /grant:r "Administrators:(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" /T /C > $null
    Write-Host "[+] SUCCESS: Admin Reclaim Complete." -ForegroundColor Green
}

Write-Host "`nOperation complete. Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")