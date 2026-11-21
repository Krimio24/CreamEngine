@echo off
setlocal

cd /d "%~dp0"

set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "ANDROID_NDK_ROOT=%ANDROID_HOME%\ndk\30.0.14904198"
set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
set "NDK_BIN=%ANDROID_NDK_ROOT%\toolchains\llvm\prebuilt\windows-x86_64\bin"

if not exist "%JAVA_HOME%\bin\java.exe" (
    echo ERROR: Android Studio JBR was not found at "%JAVA_HOME%".
    goto :failed
)

if not exist "%NDK_BIN%\clang++.exe" (
    echo ERROR: Android NDK 30.0.14904198 was not found at "%ANDROID_NDK_ROOT%".
    goto :failed
)

where lime >nul 2>nul
if errorlevel 1 (
    echo ERROR: Lime was not found on PATH. Install Haxe/Lime or add lime.exe to PATH.
    goto :failed
)

set "PATH=%NDK_BIN%;%JAVA_HOME%\bin;%PATH%"

echo Building BetterPVZ for Android (debug, ARM64)...
lime build android -debug
if errorlevel 1 goto :failed

echo.
echo Build successful.
echo APK: %~dp0export\debug\android\bin\app\build\outputs\apk\debug\Pvz-debug.apk
pause
exit /b 0

:failed
echo.
echo Android build failed. Check the errors above.
pause
exit /b 1
