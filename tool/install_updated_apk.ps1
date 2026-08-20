param(
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'

Push-Location $projectRoot
try {
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        $deviceJson = (flutter devices --machine) -join [Environment]::NewLine
        $allDevices = ConvertFrom-Json -InputObject $deviceJson
        $androidDevices = @($allDevices | Where-Object {
            $_.isSupported -and $_.targetPlatform -like 'android-*'
        })

        if ($androidDevices.Count -eq 0) {
            throw 'No Android phone found. Connect USB, enable USB debugging, and accept the phone RSA prompt.'
        }
        if ($androidDevices.Count -gt 1) {
            $deviceList = ($androidDevices | ForEach-Object { "$($_.name) [$($_.id)]" }) -join ', '
            throw "More than one Android device was found: $deviceList. Run again with -DeviceId <id>."
        }
        $DeviceId = $androidDevices[0].id
    }

    Write-Host 'Building the latest MotoMap debug APK...'
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }

    Write-Host "Installing the update on Android device $DeviceId..."
    flutter install --debug --device-id $DeviceId --use-application-binary $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not install the APK.' }

    Write-Host 'MotoMap was updated successfully. Existing app data was preserved.' -ForegroundColor Green
} finally {
    Pop-Location
}
