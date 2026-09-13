# Waits for osu! to exit, then builds the session report and opens it.
# Windows counterpart of osu-session-watch.sh. Started at login by install.ps1.

$ErrorActionPreference = 'SilentlyContinue'

$AppDir  = $PSScriptRoot
$DataDir = Join-Path $env:LOCALAPPDATA 'osu-tracker'
$Log     = Join-Path $DataDir 'watch.log'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

# How the report appears. browser = HTML in your default browser,
# term = the ANSI dashboard in a console window.
$Mode = if ($env:OSU_REPORT_MODE) { $env:OSU_REPORT_MODE } else { 'browser' }

# osu! lazer and stable both register as "osu!"; the process name has no .exe
$ProcNames = @('osu!', 'osu')

function Write-Log($msg) {
    "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg |
        Add-Content -Path $Log -Encoding UTF8
    # keep the log from growing without bound
    $lines = @(Get-Content $Log -ErrorAction SilentlyContinue)
    if ($lines.Count -gt 600) { $lines[-300..-1] | Set-Content $Log -Encoding UTF8 }
}

function Test-OsuRunning {
    foreach ($n in $ProcNames) {
        if (Get-Process -Name $n -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Find-Python {
    foreach ($c in @('python', 'py')) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { return $c }
    }
    return 'python'
}

# One watcher at a time — logging in twice shouldn't stack them
$mutex = New-Object System.Threading.Mutex($false, 'Global\osu-session-report-watch')
if (-not $mutex.WaitOne(0)) { exit 0 }

$py     = Find-Python
$report = Join-Path $AppDir 'osu-report'
Write-Log "watcher started (pid $PID, mode $Mode)"

try {
    while ($true) {
        while (-not (Test-OsuRunning)) { Start-Sleep -Seconds 20 }
        $start = Get-Date
        Write-Log "osu! detected"

        while (Test-OsuRunning) { Start-Sleep -Seconds 20 }

        # round the window up to whole hours, minimum 1
        $elapsed = [Math]::Max(1, [Math]::Ceiling(((Get-Date) - $start).TotalHours))
        Write-Log "osu! exited; session window ${elapsed}h"

        Start-Sleep -Seconds 60   # let the last score submit

        # not $args — that is an automatic variable in PowerShell
        $reportArgs = @($report, '--hours', $elapsed, '--copy')
        if ($Mode -eq 'term') {
            # a visible console so the ANSI dashboard has somewhere to draw
            Start-Process -FilePath $py -ArgumentList ($reportArgs + '--term')
        } else {
            & $py @reportArgs 2>&1 | Add-Content -Path $Log -Encoding UTF8
        }
        Write-Log "report built ($Mode), brief copied to clipboard"
    }
}
finally {
    $mutex.ReleaseMutex()
}
