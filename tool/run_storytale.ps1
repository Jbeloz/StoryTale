param(
    [string]$Device = 'web-server',
    [int]$Port = 52827
)

$root = Split-Path $PSScriptRoot -Parent

Push-Location $root
try {
    & "$PSScriptRoot\sync_voices.ps1"

    if ($Device -eq 'web-server') {
        & flutter run -d web-server --web-hostname 127.0.0.1 --web-port $Port
    }
    else {
        & flutter run -d $Device
    }
}
finally {
    Pop-Location
}
