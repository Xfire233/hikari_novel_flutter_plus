param(
  [string]$AvdName = "Hikari_API35",
  [int]$BootTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$emulator = Join-Path $sdk "emulator\emulator.exe"

$env:HOME = $env:USERPROFILE
$env:ANDROID_AVD_HOME = Join-Path $env:USERPROFILE ".android\avd"

if (!(Test-Path $adb)) {
  throw "adb.exe not found at $adb"
}
if (!(Test-Path $emulator)) {
  throw "emulator.exe not found at $emulator. Install Android SDK package 'emulator'."
}

$deviceLine = & $adb devices | Select-String -Pattern "emulator-\d+\s+device" | Select-Object -First 1
if ($null -eq $deviceLine) {
  Start-Process -FilePath $emulator -ArgumentList @("@$AvdName", "-gpu", "swiftshader_indirect", "-no-snapshot-load", "-no-metrics")
}

& $adb wait-for-device
$deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
do {
  Start-Sleep -Seconds 3
  $boot = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
} while ($boot -ne "1" -and (Get-Date) -lt $deadline)

if ($boot -ne "1") {
  throw "Android emulator did not finish booting within $BootTimeoutSeconds seconds."
}

& $adb devices -l
