# Boots the discipletrack emulator, installs the debug APK and launches the app.
#
# Written for a memory-constrained host. The emulator forces a 2.5 GB minimum
# for the android-35 system image, so it needs VS Code closed to fit inside
# 7.7 GB alongside Docker.
#
# Usage, from a normal PowerShell window (NOT VS Code's terminal):
#   cd D:\karl\discipletrack
#   powershell -ExecutionPolicy Bypass -File tool\run_on_emulator.ps1

# Deliberately NOT 'Stop'. PowerShell 5.1 wraps any stderr output from a native
# executable in a NativeCommandError, and adb writes routine progress messages
# such as "device offline" to stderr while the emulator boots. Under 'Stop'
# those harmless messages abort the script mid-wait.
$ErrorActionPreference = 'Continue'

$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
$emu = "$sdk\emulator\emulator.exe"
$apk = "$PSScriptRoot\..\build\app\outputs\flutter-apk\app-debug.apk"

function Show-Ram {
    $os = Get-CimInstance Win32_OperatingSystem
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    Write-Host "   free RAM: $free GB (emulator needs ~2.5 GB)" -ForegroundColor DarkGray
    return $free
}

Write-Host "`n=== 1. Checking memory ===" -ForegroundColor Cyan
$free = Show-Ram
if ($free -lt 2.3) {
    Write-Host "   WARNING: under 2.3 GB free. Close VS Code and any browser, then re-run." -ForegroundColor Yellow
    Write-Host "   Continuing anyway, but the emulator may hang mid-boot." -ForegroundColor Yellow
}

Write-Host "`n=== 2. Clearing any stuck emulator ===" -ForegroundColor Cyan
Get-Process -Name "qemu*", "emulator*" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Host "   done"

Write-Host "`n=== 3. Starting emulator (host GPU, detached) ===" -ForegroundColor Cyan
cmd.exe /c start "" /B "$emu" -avd discipletrack -gpu host -no-boot-anim
Write-Host "   launched, waiting for boot (up to 5 minutes)..."

$booted = $false
for ($i = 1; $i -le 60; $i++) {
    Start-Sleep -Seconds 5
    if (-not (Get-Process -Name "qemu-system-x86_64" -ErrorAction SilentlyContinue)) {
        Write-Host "`n   EMULATOR DIED after $($i*5)s. Not enough free RAM." -ForegroundColor Red
        Show-Ram | Out-Null
        Write-Host "   Close more applications and re-run this script." -ForegroundColor Red
        exit 1
    }
    # adb chatters on stderr while the device is offline; swallow it entirely.
    $state = ""
    try { $state = (& $adb shell getprop sys.boot_completed 2>&1 | Out-String).Trim() } catch { }
    if ($state -eq "1") { $booted = $true; Write-Host "`n   BOOTED after $($i*5)s" -ForegroundColor Green; break }
    Write-Host "." -NoNewline
}

if (-not $booted) {
    Write-Host "`n   TIMED OUT. The emulator is up but Android never finished booting," -ForegroundColor Red
    Write-Host "   which almost always means it is starved of memory." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== 4. Installing DiscipleTrack ===" -ForegroundColor Cyan
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) { Write-Host "   install failed" -ForegroundColor Red; exit 1 }

Write-Host "`n=== 5. Launching ===" -ForegroundColor Cyan
& $adb shell am start -n com.discipletrack.discipletrack/.MainActivity | Out-Null
Start-Sleep -Seconds 5
$pidOut = (& $adb shell pidof com.discipletrack.discipletrack 2>$null) -replace "`r", ""

if ($pidOut) {
    Write-Host "`n   RUNNING (pid $pidOut)" -ForegroundColor Green
    Write-Host "`n   Sign in with:  user@dev.com" -ForegroundColor White
    Write-Host "   (or register a new account)" -ForegroundColor DarkGray
    Write-Host "`n   You can reopen VS Code now." -ForegroundColor White
} else {
    Write-Host "`n   App did not start. Reopen VS Code and check with Claude." -ForegroundColor Red
}
