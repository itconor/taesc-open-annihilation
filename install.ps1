<#
Installs TA: Escalation (TAESC) as an Open Annihilation mod, on Windows.

It copies TAESC's own archives from a TAESC install you already have (or a
TAESC .zip you downloaded), adds this repository's oamod.yaml, and puts the
result in Open Annihilation's Mods folder. It never deletes anything: a mod
already installed under the same name is renamed to a backup first.

  .\install.ps1                        find TAESC on this PC and install it
  .\install.ps1 -Source PATH           PATH is a TAESC folder or a TAESC .zip
  .\install.ps1 -Package taesc.oamod   build a .oamod package instead of installing
  .\install.ps1 -ModsDir DIR           install into DIR instead of the usual Mods folder

If Windows refuses to run it, start it with:
  powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
[CmdletBinding()]
param(
    [string]$Source = "",
    [string]$ModsDir = "",
    [string]$Package = ""
)
$ErrorActionPreference = "Stop"

$TestedVersion = "10.2.0"
$ModId = "taesc"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProfileYaml = Join-Path $Here "mod\oamod.yaml"

function Fail($msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }
function Warn($msg) { Write-Host "warning: $msg" -ForegroundColor Yellow }

if (-not (Test-Path $ProfileYaml)) { Fail "mod\oamod.yaml is missing next to this script" }

# Prints the folder that holds TAESC.gp3 under $root, or $null.
function Find-Taesc([string]$root, [int]$depth = 6) {
    if (-not (Test-Path $root)) { return $null }
    $hit = Get-ChildItem -Path $root -Filter "TAESC.gp3" -File -Recurse -Depth $depth -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($hit) { return $hit.DirectoryName }
    return $null
}

# ------------------------------------------------------------------ find TAESC
$TaescDir = $null
if ($Source) {
    if (-not (Test-Path $Source)) { Fail "$Source does not exist" }
    if ((Get-Item $Source).PSIsContainer) {
        $TaescDir = Find-Taesc $Source
        if (-not $TaescDir) { Fail "no TAESC.gp3 under $Source; is this a TAESC install?" }
    } elseif ($Source -match '\.zip$') {
        $work = Join-Path ([IO.Path]::GetTempPath()) ("taesc-unpack-" + [guid]::NewGuid().ToString("N"))
        Write-Host "Unpacking $Source into $work ..."
        Expand-Archive -Path $Source -DestinationPath $work
        $TaescDir = Find-Taesc $work
        if (-not $TaescDir) { Fail "no TAESC.gp3 in $Source" }
    } elseif ($Source -match '\.exe$') {
        Fail "$Source is the TAESC installer. Run it first, then run this script again; it will find the installed copy."
    } else {
        Fail "$Source is not a folder or a .zip (unpack it first, then pass the folder)"
    }
} else {
    Write-Host "Looking for a TAESC install ..."
    $roots = @(
        "C:\GOG Games", "D:\GOG Games",
        "C:\Program Files (x86)\GOG Galaxy\Games", "C:\Program Files (x86)\GOG.com",
        "C:\Program Files (x86)\Steam\steamapps\common",
        "C:\Program Files (x86)", "C:\Program Files",
        "C:\Games", "D:\Games", "C:\CAVEDOG", "C:\TA", "C:\TAESC"
    )
    foreach ($r in $roots) {
        $TaescDir = Find-Taesc $r 3
        if ($TaescDir) { break }
    }
    if (-not $TaescDir) { Fail "no TAESC install found. Install TAESC first (https://taesc.tauniverse.com), then run: .\install.ps1 -Source 'C:\path\to\TAESC'" }
}
Write-Host "TAESC found in: $TaescDir"

# ------------------------------------------------------------------ version check
$version = ""
$gold = Get-ChildItem -Path $TaescDir -Filter "GOLD_*.txt" -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($gold -and $gold.Name -match '^GOLD_(\d+)_(\d+)_(\d+)\.') { $version = "$($Matches[1]).$($Matches[2]).$($Matches[3])" }
if (-not $version) {
    $ini = Join-Path $TaescDir "TAESC.ini"
    if (Test-Path $ini) {
        $m = Select-String -Path $ini -Pattern 'v(\d+(\.\d+)+)' -List | Select-Object -First 1
        if ($m) { $version = $m.Matches[0].Groups[1].Value }
    }
}
if ($version -eq $TestedVersion) { Write-Host "TAESC version: $version" }
else { Warn "this profile was made for TAESC $TestedVersion; this install is $(if ($version) { $version } else { 'of an unknown version' }). It is installed anyway, but check it plays as it should." }

# ------------------------------------------------------------------ stage the mod
$stageRoot = Join-Path ([IO.Path]::GetTempPath()) ("taesc-mod-" + [guid]::NewGuid().ToString("N"))
$Stage = Join-Path $stageRoot $ModId
New-Item -ItemType Directory -Path $Stage -Force | Out-Null

function Copy-Matching([string]$pattern) {
    $files = @(Get-ChildItem -Path $TaescDir -Filter $pattern -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) { Copy-Item -LiteralPath $f.FullName -Destination $Stage }
    return $files.Count
}

Write-Host "Copying TAESC's files ..."
if ((Copy-Matching "TAESC.gp3") -ne 1) { Fail "TAESC.gp3 could not be copied" }
$ufos = Copy-Matching "*ESC*.ufo"
if ($ufos -lt 1) { Fail "no TAESC .ufo archives (T2ESC.ufo ...) next to TAESC.gp3" }
Copy-Matching "TADEMO.ufo" | Out-Null
Copy-Matching "TAESC.ini" | Out-Null
Copy-Matching "GOLD_*.txt" | Out-Null
$icon = Join-Path $TaescDir "Icon"
if (Test-Path $icon) { Copy-Item -LiteralPath $icon -Destination (Join-Path $Stage "Icon") -Recurse }
$music = Join-Path $TaescDir "Music"
if (Test-Path $music) { Copy-Item -LiteralPath $music -Destination (Join-Path $Stage "music") -Recurse }
Copy-Item -LiteralPath $ProfileYaml -Destination (Join-Path $Stage "oamod.yaml")
Write-Host "  TAESC.gp3, $ufos TAESC archives, TAESC.ini, Icon and music"

# ------------------------------------------------------------------ check with the engine
$oa = @(
    "C:\Games\Open Annihilation\open-annihilation.exe",
    "$env:ProgramFiles\Open Annihilation\open-annihilation.exe",
    "${env:ProgramFiles(x86)}\Open Annihilation\open-annihilation.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($oa) {
    $out = & $oa --print-profile --mod-dir $Stage 2>&1
    if ($LASTEXITCODE -ne 0) { $out | Write-Host; Fail "Open Annihilation refused the profile (above)" }
    $hash = $out | Where-Object { "$_" -like "sha256-sim*" } | Select-Object -First 1
    Write-Host "Open Annihilation accepts the profile ($hash)"
} else {
    Warn "Open Annihilation not found, so the profile was not checked; it is checked when the game starts"
}

# ------------------------------------------------------------------ package or install
if ($Package) {
    if ($Package -notmatch '\.oamod$') { $Package = "$Package.oamod" }
    $Package = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Package))
    if (Test-Path $Package) { Fail "$Package already exists; pick another name" }
    # ZipFile rather than Compress-Archive: Windows PowerShell 5.1's
    # Compress-Archive writes backslashes into entry names, which the
    # .oamod installer refuses.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($Stage, $Package, [IO.Compression.CompressionLevel]::Optimal, $true)
    Write-Host ""
    Write-Host "Built $Package"
    Write-Host "Open it with Open Annihilation (double-click it, or drag it onto the game's window) to install it."
    exit 0
}

if (-not $ModsDir) {
    $ModsDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Open Annihilation\Mods"
}
New-Item -ItemType Directory -Path $ModsDir -Force | Out-Null
$dest = Join-Path $ModsDir $ModId
if (Test-Path $dest) {
    # Backups go beside the Mods folder, not in it: the Library lists every
    # folder in Mods, and a backup there would show up as a second TAESC.
    $backups = Join-Path (Split-Path -Parent $ModsDir) "Mod backups"
    New-Item -ItemType Directory -Path $backups -Force | Out-Null
    $backup = Join-Path $backups ("$ModId-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Move-Item -LiteralPath $dest -Destination $backup
    Write-Host "An earlier copy was moved to $backup (delete it yourself once you are happy)"
}
Move-Item -LiteralPath $Stage -Destination $dest

Write-Host ""
Write-Host "Installed TA: Escalation in $dest"
Write-Host ""
Write-Host "To play: open Open Annihilation, press OA on the main menu, choose TA: Escalation and"
Write-Host "press Play now. Core Contingency and Battle Tactics must be switched on: TAESC uses both."
