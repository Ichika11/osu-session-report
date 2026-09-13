# osu-session-report installer for Windows.
#
# Run from PowerShell:
#     powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Safe to re-run: it skips what is already done and never overwrites your
# config. Does not need administrator rights.

$ErrorActionPreference = 'Stop'

$AppDir  = Join-Path $env:LOCALAPPDATA 'Programs\osu-session-report'
$CfgDir  = Join-Path $env:APPDATA      'osu-tracker'
$Cfg     = Join-Path $CfgDir           'config.json'
$DataDir = Join-Path $env:LOCALAPPDATA 'osu-tracker'
$Src     = $PSScriptRoot

function Ok    ($m) { Write-Host "  [ok] $m"   -ForegroundColor Green }
function Warn  ($m) { Write-Host "  [!] $m"    -ForegroundColor Yellow }
function Fail  ($m) { Write-Host "  [x] $m"    -ForegroundColor Red }
function Step  ($m) { Write-Host ""; Write-Host $m -ForegroundColor White }

Write-Host ""
Write-Host "  osu! session report - installer" -ForegroundColor Cyan
Write-Host "  builds a visual dashboard when you close osu!" -ForegroundColor DarkGray

# ------------------------------------------------------------------ python --
Step "1. Checking Python"
$py = $null
foreach ($c in @('python', 'py')) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) {
        # the Microsoft Store stub is a 0-byte shim that opens the Store
        $v = & $c -c "import sys;print('%d.%d' % sys.version_info[:2])" 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) { $py = $c; break }
    }
}
if (-not $py) {
    Fail "Python not found."
    Write-Host "      Install it from https://www.python.org/downloads/"
    Write-Host "      IMPORTANT: tick 'Add python.exe to PATH' in the installer."
    exit 1
}
$ver = & $py -c "import sys;print('%d.%d' % sys.version_info[:2])"
& $py -c "import sys;sys.exit(0 if sys.version_info >= (3,9) else 1)"
if ($LASTEXITCODE -ne 0) { Fail "Python $ver is too old; 3.9 or newer is needed."; exit 1 }
Ok "Python $ver ($py)"

# ------------------------------------------------------------ python deps --
Step "2. Installing Python packages"
$missing = @()
foreach ($m in @(@('ossapi','ossapi'), @('circleguard','circleguard'), @('PIL','pillow'))) {
    & $py -c "import $($m[0])" 2>$null
    if ($LASTEXITCODE -ne 0) { $missing += $m[1] }
}
if ($missing.Count -eq 0) {
    Ok "ossapi, circleguard, pillow already present"
} else {
    Write-Host "     installing: $($missing -join ', ')  (this can take a minute)"
    & $py -m pip install --user --quiet --upgrade @missing
    if ($LASTEXITCODE -ne 0) {
        Fail "pip failed. Try manually:"
        Write-Host "      $py -m pip install --user ossapi circleguard pillow"
        exit 1
    }
    Ok "installed $($missing -join ', ')"
}

# ------------------------------------------------------------------- files --
Step "3. Installing to $AppDir"
New-Item -ItemType Directory -Force -Path $AppDir, $DataDir | Out-Null
foreach ($f in @('osu-report', 'osu-stats', 'osu-session-watch.ps1')) {
    $from = Join-Path $Src (Join-Path 'bin' $f)
    if (-not (Test-Path $from)) { $from = Join-Path $Src $f }
    Copy-Item $from (Join-Path $AppDir $f) -Force
    Ok $f
}

# .cmd shims so `osu-report` works as a plain command
foreach ($n in @('osu-report', 'osu-stats')) {
    @"
@echo off
$py "%~dp0$n" %*
"@ | Set-Content -Path (Join-Path $AppDir "$n.cmd") -Encoding ASCII
}
Ok "created osu-report.cmd and osu-stats.cmd"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$AppDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$AppDir", 'User')
    Ok "added $AppDir to your PATH"
    Warn "open a NEW terminal before the osu-report command works"
} else {
    Ok "already on your PATH"
}

# ----------------------------------------------------------------- config --
Step "4. osu! API credentials"
New-Item -ItemType Directory -Force -Path $CfgDir | Out-Null

if (Test-Path $Cfg) {
    Ok "config already exists at $Cfg (left untouched)"
} else {
    Write-Host @'
     You need two things from https://osu.ppy.sh/home/account/edit

     A) OAuth application  (scroll to "OAuth")
        - click "New OAuth Application"
        - Application Name:  anything, e.g. session report
        - Application Callback URL:  http://localhost:8727/
          ^ must match EXACTLY, including the trailing slash
        - Register, then note the Client ID and Client Secret

     B) Legacy API key  (scroll to "Legacy API")
        - click "New Legacy API Key", any name
        - used to fetch beatmaps for the unstable-rate calculation

'@
    $user   = Read-Host "     Your osu! username"
    $id     = Read-Host "     Client ID"
    $secret = Read-Host "     Client Secret" -AsSecureString
    $key    = Read-Host "     Legacy API key (optional, press Enter to skip)" -AsSecureString

    $plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret))
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($key))

    [ordered]@{
        client_id     = $id
        client_secret = $plainSecret
        username      = $user
        mode          = 'osu'
        api_key       = $plainKey
        redirect_uri  = 'http://localhost:8727/'
        replay_dir    = ''
    } | ConvertTo-Json | Set-Content -Path $Cfg -Encoding UTF8

    # lock the file down to the current user only
    $acl = Get-Acl $Cfg
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, 'FullControl', 'Allow')))
    Set-Acl -Path $Cfg -AclObject $acl
    Ok "wrote $Cfg (readable only by you)"
}

# -------------------------------------------------------------- autostart --
Step "5. Run automatically when you close osu!?"
Write-Host "     A background watcher notices osu! exit and builds the report."
Write-Host "     You can skip this and run osu-report by hand instead."
Write-Host ""
Write-Host "       1) Yes - start it at login"
Write-Host "       2) Skip"
$choice = Read-Host "     Choose [1/2]"

if ($choice -eq '1') {
    $startup = [Environment]::GetFolderPath('Startup')
    $shim    = Join-Path $startup 'osu-session-report.cmd'
    $watcher = Join-Path $AppDir 'osu-session-watch.ps1'
    @"
@echo off
start "" /min powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$watcher"
"@ | Set-Content -Path $shim -Encoding ASCII
    Ok "added to your Startup folder"
    Write-Host "     starting it now..."
    Start-Process powershell -ArgumentList @(
        '-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$watcher
    ) -WindowStyle Hidden
    Ok "watcher running"
} else {
    Ok "skipped - run 'osu-report' yourself whenever you like"
}

# ------------------------------------------------------------------- done --
Step "Done"
Write-Host @"
     Open a NEW terminal, then try:

       osu-report            full dashboard, opens in your browser
       osu-report --term     same data drawn in the terminal
       osu-report --brief    a Markdown summary for feeding to an AI

     The first run downloads a few replays, so give it a moment.
     Reports are written to $DataDir\reports\

"@
