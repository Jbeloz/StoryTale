param(
    [string]$Device = 'web-server',
    [int]$Port = 52827
)

$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
$flutterEnv = Join-Path $root '.env.flutter'

function Get-EnvValue([string]$Name) {
    if (-not (Test-Path $envFile)) { return '' }
    $line = Get-Content $envFile | Where-Object { $_ -match "^$Name=" } | Select-Object -Last 1
    if (-not $line) { return '' }
    return ($line -split '=', 2)[1].Trim()
}

function Get-AndroidDeviceId {
    $allDevices = (& flutter devices --machine) | ConvertFrom-Json
    $devices = @($allDevices |
        Where-Object { $_.targetPlatform -like 'android-*' -and $_.isSupported })

    if ($devices.Count -eq 0) {
        throw 'No Android phone found. Connect and unlock the phone, then allow USB debugging.'
    }
    if ($devices.Count -gt 1) {
        $ids = ($devices | ForEach-Object { "$($_.name) ($($_.id))" }) -join ', '
        throw "More than one Android device found: $ids. Run again using -Device followed by the chosen ID."
    }

    Write-Host "Using Android phone: $($devices[0].name) ($($devices[0].id))"
    return $devices[0].id
}

Push-Location $root
$poseAdmin = $null
try {
    if ($Device -eq 'android') {
        $Device = Get-AndroidDeviceId
    }

    & "$PSScriptRoot\sync_voices.ps1"

    if ($Device -eq 'web-server') {
        $poseAdmin = Start-Process -FilePath 'dart' `
            -ArgumentList @('run', 'tool/pose_admin_server.dart') `
            -WorkingDirectory $root `
            -WindowStyle Hidden `
            -PassThru
    }

    $imageToken = Get-EnvValue 'CLOUDFLARE_IMAGE_TOKEN'
    $imageUrl = Get-EnvValue 'CLOUDFLARE_IMAGE_URL'
    if (-not $imageUrl) {
        $imageUrl = 'https://storytale-image-worker.jbalejoshift0928.workers.dev'
    }

    $flutterOptions = @()
    if ($imageToken) {
        @(
            "CLOUDFLARE_IMAGE_URL=$imageUrl"
            "CLOUDFLARE_IMAGE_TOKEN=$imageToken"
        ) | Set-Content -LiteralPath $flutterEnv
        $flutterOptions += "--dart-define-from-file=$flutterEnv"
    }

    if ($Device -eq 'build-web') {
        & flutter build web --no-pub --no-wasm-dry-run @flutterOptions
    }
    elseif ($Device -eq 'web-server') {
        & flutter run -d web-server --web-hostname 127.0.0.1 --web-port $Port @flutterOptions
    }
    else {
        & flutter run -d $Device @flutterOptions
    }
}
finally {
    if ($poseAdmin -and -not $poseAdmin.HasExited) {
        Stop-Process -Id $poseAdmin.Id -Force
    }
    Remove-Item -LiteralPath $flutterEnv -ErrorAction SilentlyContinue
    Pop-Location
}
