---
name: hikari-novel-local-android
description: "Use for Hikari Novel Flutter Android local development in C:\\Users\\test\\Desktop\\Code\\hikari_novel_flutter: starting the Hikari_API35 emulator, installing or running debug APKs, capturing adb evidence, running Flutter analyze/test/build with fixed Windows paths, or avoiding repeated discovery of SDK, Java, adb, emulator, and Flutter tool locations."
---

# Hikari Novel Local Android

Use this skill whenever working on this repo needs Android/Flutter validation. Do not rediscover PATH, Java, Flutter, adb, emulator, package name, or build commands unless a command fails and the failure suggests the environment changed.

## Fixed Environment

- Repo: `C:\Users\test\Desktop\Code\hikari_novel_flutter`
- Android SDK: `C:\Users\test\AppData\Local\Android\Sdk`
- adb: `C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- emulator: `C:\Users\test\AppData\Local\Android\Sdk\emulator\emulator.exe`
- AVD: `Hikari_API35`
- Default emulator device id: `emulator-5554`
- App id: `pers.cyh128.hikari_novel_plus`
- Main activity: `pers.cyh128.hikari_novel_plus/.MainActivity`
- Dart: `C:\flutter\bin\cache\dart-sdk\bin\dart.exe`
- Flutter tool entrypoint: `C:\flutter\packages\flutter_tools\bin\flutter_tools.dart`
- Java home: `C:\Program Files\Android\Android Studio\jbr`
- PowerShell executable: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Bundled Python, if needed: `C:\Users\test\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`
- UIAutomator2 MCP venv: `C:\Users\test\.codex\tools\uiautomator2-mcp\.venv`
- UIAutomator2 MCP command: `C:\Users\test\.codex\tools\uiautomator2-mcp\.venv\Scripts\u2mcp.exe stdio`

Always prefix Flutter commands with:

```powershell
$env:Path = 'C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\flutter\bin;' + $env:Path
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
```

Prefer direct Flutter tool invocation:

```powershell
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'C:\flutter\packages\flutter_tools\bin\flutter_tools.dart' <args>
```

Avoid `flutter.bat`, bare `flutter`, bare `dart`, bare `python`, and bare `powershell`; these often fail in this environment.

## Fast Workflows

Start or reuse the emulator:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File tool\start_android_emulator.ps1
```

Build debug APK, install to emulator, and launch:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File tool\install_debug_emulator.ps1
```

Run with Flutter hot reload:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File tool\flutter_run_emulator.ps1
```

Run analyze:

```powershell
$env:Path = 'C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\flutter\bin;' + $env:Path
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'C:\flutter\packages\flutter_tools\bin\flutter_tools.dart' analyze lib test\book_tags_test.dart test\esj_parser_test.dart test\widget_test.dart
```

Run tests:

```powershell
$env:Path = 'C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\flutter\bin;' + $env:Path
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'C:\flutter\packages\flutter_tools\bin\flutter_tools.dart' test
```

Build release APK:

```powershell
$env:Path = 'C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\flutter\bin;' + $env:Path
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'C:\flutter\packages\flutter_tools\bin\flutter_tools.dart' build apk --release
```

## Emulator State Checks

Use these before assuming the emulator is broken:

```powershell
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' devices -l
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell getprop sys.boot_completed
& 'C:\Users\test\AppData\Local\Android\Sdk\emulator\emulator.exe' -accel-check
```

Expected state after setup:

- `adb devices -l` shows `emulator-5554 ... device`.
- `sys.boot_completed` is `1`.
- `-accel-check` reports `WHPX ... is installed and usable`.

If `emulator.exe` or the AVD is missing, install official SDK packages only after approval:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:Path='C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;' + $env:JAVA_HOME + '\bin;' + $env:Path
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --install "emulator" "system-images;android-35;google_apis;x86_64"
'no' | & "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd --force --name Hikari_API35 --package "system-images;android-35;google_apis;x86_64" --device "Nexus 5X"
```

## Runtime Evidence

Confirm app is foreground:

```powershell
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell pidof pers.cyh128.hikari_novel_plus
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell dumpsys window | Select-String -Pattern 'mCurrentFocus|mFocusedApp'
```

Capture screenshot:

```powershell
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell screencap -p /sdcard/hikari_screen.png
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 pull /sdcard/hikari_screen.png .dart_tool\hikari_screen.png
```

Check recent app logs:

```powershell
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 logcat -d -t 300 | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime|pers.cyh128.hikari_novel_plus|Flutter|ActivityTaskManager'
```

## UIAutomator2 MCP

The uiautomator2 MCP server is installed locally for faster emulator UI inspection and interaction. It is registered in `C:\Users\test\.codex\config.toml` as:

```toml
[mcp_servers.uiautomator2]
command = "C:\\Users\\test\\.codex\\tools\\uiautomator2-mcp\\.venv\\Scripts\\u2mcp.exe"
args = ["stdio"]
```

The MCP tools may require a new Codex session before they appear in the tool list. Once available, prefer them for structured Android UI work:

- `device_list`, `connect`, `init`, and `app_current` for setup and state.
- `dump_hierarchy` and screenshots for fast layout assertions.
- `click`, `swipe`, `send_keys`, and `get_toast` for interaction checks.

For this AVD, use `emulator-5554` as the default device. A normal UIAutomator2
inspection loop is:

1. Start or reuse `Hikari_API35`, then confirm `adb devices -l` shows
   `emulator-5554 ... device`.
2. Run `u2mcp doctor`; if it reports the device is ready, prefer MCP
   `connect`/`init`/`app_current` over raw adb for UI state.
3. Launch the app with MCP `app_start` using package
   `pers.cyh128.hikari_novel_plus`, or fall back to adb:

```powershell
& 'C:\Users\test\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s emulator-5554 shell am start -n pers.cyh128.hikari_novel_plus/.MainActivity
```

4. Use MCP `dump_hierarchy` before tapping; target Flutter semantics text via
   content descriptions such as `首页`, `书架`, `我的`, `推荐`, `分类`,
   `排行榜`, `完结`, and source names.
5. Use MCP `save_screenshot` for evidence, then inspect logcat only for
   crashes or network/parser errors.

Fallback to raw adb commands in this skill when the MCP server is not loaded in the current session or the emulator is offline. Quick local checks:

```powershell
$env:PYTHONUTF8='1'
$env:PYTHONIOENCODING='utf-8'
& 'C:\Users\test\.codex\tools\uiautomator2-mcp\.venv\Scripts\u2mcp.exe' --version
& 'C:\Users\test\.codex\tools\uiautomator2-mcp\.venv\Scripts\u2mcp.exe' tools
& 'C:\Users\test\.codex\tools\uiautomator2-mcp\.venv\Scripts\u2mcp.exe' doctor
```

Set the UTF-8 environment variables before `doctor` or `tools`; otherwise Rich output can fail in the Windows GBK console while printing status symbols.

If a direct `uiautomator2.exe` CLI call fails with
`AccessibilityServiceAlreadyRegisteredError`, another UIAutomator session is
already active. Retry once with `u2mcp doctor`; if screenshots or hierarchy are
still needed immediately, fall back to adb `uiautomator dump` / `screencap`
instead of restarting the emulator.

## Known Non-Issues

- `analyze` currently reports an existing info: `lib\models\user_info.g.dart:9:7 user_info_adapter camel_case_types`.
- Flutter may print dependency updates. Do not treat them as task blockers.
- Flutter SDK cache lockfile access may require escalation.
- `where` not found means `C:\Windows\System32` is missing from PATH; use the fixed PATH prefix above.
