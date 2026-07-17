$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root '.tools\rvc-venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $python)) {
    throw "StoryTale voice environment was not found: $python"
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
