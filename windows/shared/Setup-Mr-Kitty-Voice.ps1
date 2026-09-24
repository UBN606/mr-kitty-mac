$ErrorActionPreference = 'Stop'
$candidates = @($env:MR_KITTY_PYTHON,
    (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'))
$command = Get-Command python.exe -ErrorAction SilentlyContinue
if ($command) { $candidates += $command.Source }
$python = $null
foreach ($candidate in $candidates) {
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate)) { continue }
    & $candidate --version 2>$null
    if ($LASTEXITCODE -eq 0) { $python = $candidate; break }
}
if (-not $python) {
    throw 'Python 3.10+ is needed. Install Python, then run this setup again.'
}
$voiceHome = Join-Path $PSScriptRoot 'voice'
$venvPython = Join-Path $voiceHome 'venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    & $python -m venv (Join-Path $voiceHome 'venv')
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the voice environment.' }
}
if (-not (Test-Path -LiteralPath (Join-Path $voiceHome 'venv/Lib/site-packages/pip'))) {
    & $venvPython -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) { throw 'Could not add pip to the voice environment.' }
}
& $venvPython -m pip install --no-input --disable-pip-version-check 'kokoro-onnx==0.6.1' 'soundfile==0.14.0'
if ($LASTEXITCODE -ne 0) { throw 'Could not install the local voice runtime.' }
& $venvPython (Join-Path $PSScriptRoot 'Get-Mr-Kitty-Voice-Model.py') (Join-Path $voiceHome 'model')
if ($LASTEXITCODE -ne 0) { throw 'Could not download the local voice model.' }
Write-Output 'Mr. Kitty voice is installed. Press Hear in Kitty chat to try it.'
