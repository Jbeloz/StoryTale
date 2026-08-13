$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root '.tools\rvc-venv\Scripts\python.exe'

# A missing voice environment skips this step instead of stopping the launcher.
#
# `run_storytale.ps1` calls this script with `&` inside its own try/finally and
# no catch, so a `throw` here used to propagate and kill the launcher before it
# ever reached `flutter run`, so the app would not start at all just because a
# 6.2 GB Python toolchain was absent.
#
# Nothing at runtime needs it. The narration in assets/audio/ is already
# generated and tracked, and the app only plays those files. This environment
# is required solely to generate NEW audio, so its absence is a reason to skip,
# not to fail.
#
# Rebuild it from tool/rvc-requirements.txt; that file carries the exact
# command, including the CUDA index URL that plain pip would miss.
if (-not (Test-Path -LiteralPath $python)) {
    Write-Host 'Voice environment not found; skipping narration sync.'
    Write-Host 'Existing narration still plays. See tool/rvc-requirements.txt to rebuild.'
    return
}

Push-Location $root
try {
    & $python 'tool\sync_voice_audio.py'
    if ($LASTEXITCODE -ne 0) {
        throw "Voice sync failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
