# Removes osu-session-report from Windows.
# Data and credentials are kept unless you pass -Purge.
#
#     powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
#     powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -Purge

param([switch]$Purge)

$ErrorActionPreference = 'SilentlyContinue'

$AppDir  = Join-Path $env:LOCALAPPDATA 'Programs\osu-session-report'
$CfgDir  = Join-Path $env:APPDATA      'osu-tracker'
$DataDir = Join-Path $env:LOCALAPPDATA 'osu-tracker'
$Startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'osu-session-report.cmd'

function Ok   ($m) { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "  [!] $m"  -ForegroundColor Yellow }

Write-Host ""
Write-Host "Removing osu-session-report..."

# stop any watcher: PowerShell processes whose command line names our script
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" |
    Where-Object { $_.CommandLine -like '*osu-session-watch*' } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
        Ok "stopped watcher (pid $($_.ProcessId))"
    }

if (Test-Path $Startup) { Remove-Item $Startup -Force; Ok "removed the Startup entry" }

if (Test-Path $AppDir) { Remove-Item $AppDir -Recurse -Force; Ok "removed $AppDir" }

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -like "*$AppDir*") {
    $clean = ($userPath -split ';' | Where-Object { $_ -and $_ -ne $AppDir }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $clean, 'User')
    Ok "removed it from your PATH"
}

if ($Purge) {
    Remove-Item $DataDir, $CfgDir -Recurse -Force
    Ok "purged data and credentials"
} else {
    Warn "kept your data:        $DataDir"
    Warn "kept your credentials: $CfgDir"
    Write-Host "       re-run with -Purge to delete them too"
}
Write-Host ""
