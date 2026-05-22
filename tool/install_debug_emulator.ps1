param(
  [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$dart = "C:\flutter\bin\cache\dart-sdk\bin\dart.exe"
$flutterTools = "C:\flutter\packages\flutter_tools\bin\flutter_tools.dart"
$javaHome = "C:\Program Files\Android\Android Studio\jbr"
$apk = Join-Path $repo "build\app\outputs\flutter-apk\app-debug.apk"

if (!(Test-Path $adb)) {
  throw "adb.exe not found at $adb"
}
if (!(Test-Path $dart)) {
  throw "Dart SDK not found at $dart"
}
if (!(Test-Path $flutterTools)) {
  throw "Flutter tools entrypoint not found at $flutterTools"
}

$env:JAVA_HOME = $javaHome
$env:Path = "C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\flutter\bin;$($env:Path)"

Push-Location $repo
try {
  & $dart $flutterTools build apk --debug
  & $adb -s $DeviceId install -r $apk
  & $adb -s $DeviceId shell am start -n pers.cyh128.hikari_novel_plus/.MainActivity
} finally {
  Pop-Location
}
