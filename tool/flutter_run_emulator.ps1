param(
  [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$dart = "C:\flutter\bin\cache\dart-sdk\bin\dart.exe"
$flutterTools = "C:\flutter\packages\flutter_tools\bin\flutter_tools.dart"
$javaHome = "C:\Program Files\Android\Android Studio\jbr"

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
  & $dart $flutterTools run -d $DeviceId
} finally {
  Pop-Location
}
