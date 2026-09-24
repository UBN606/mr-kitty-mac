$ErrorActionPreference = 'Stop'
$runtime = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$copet = $env:MR_KITTY_COPET_EXE
if (-not $copet) {
    $command = Get-Command 'CoPet.exe' -ErrorAction SilentlyContinue
    if ($command) { $copet = $command.Source }
}
$controller = Join-Path $PSScriptRoot 'Mr-Kitty-Controller.ps1'
$watcher = Join-Path $PSScriptRoot 'Mr-Kitty-Codex-Watcher.py'
$pythonw = $env:MR_KITTY_PYTHONW
if (-not $pythonw) {
    $command = Get-Command 'pythonw.exe' -ErrorAction SilentlyContinue
    if ($command) { $pythonw = $command.Source }
}
if (-not (Get-Process CoPet -ErrorAction SilentlyContinue)) {
    if (-not $copet -or -not (Test-Path -LiteralPath $copet)) {
        'CoPet is not running. Set MR_KITTY_COPET_EXE to its full path, then restart.' |
            Set-Content -LiteralPath (Join-Path $runtime 'start-error.txt')
        exit 1
    }
    Start-Process -FilePath $copet
    Start-Sleep -Seconds 2
}
Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-Sta', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
    '-File', ('"' + $controller + '"')
) -WindowStyle Hidden
if ($pythonw -and (Test-Path -LiteralPath $watcher) -and (Test-Path -LiteralPath $pythonw)) {
    Start-Process -FilePath $pythonw -ArgumentList @(('"' + $watcher + '"')) -WindowStyle Hidden
}
