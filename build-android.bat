@echo off
setlocal

cd /d "%~dp0"

set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "ANDROID_NDK_ROOT=%ANDROID_HOME%\ndk\30.0.14904198"
set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
set "NDK_BIN=%ANDROID_NDK_ROOT%\toolchains\llvm\prebuilt\windows-x86_64\bin"
set "APP_DIR=%~dp0export\release\android\bin\app"
set "SIGNING_FILE=%APP_DIR%\signing.properties"
set "DEBUG_KEYSTORE=%USERPROFILE%\.android\debug.keystore"
set "DEBUG_KEYSTORE_GRADLE=%USERPROFILE:\=/%/.android/debug.keystore"

if not exist "%JAVA_HOME%\bin\java.exe" (
    echo ERROR: Android Studio JBR was not found at "%JAVA_HOME%".
    goto :failed
)

if not exist "%NDK_BIN%\clang++.exe" (
    echo ERROR: Android NDK 30.0.14904198 was not found at "%ANDROID_NDK_ROOT%".
    goto :failed
)

if not exist "%SIGNING_FILE%" (
    if not exist "%DEBUG_KEYSTORE%" (
        echo ERROR: No Android signing key was found at "%DEBUG_KEYSTORE%".
        echo Add signing.properties to "%APP_DIR%" or install Android Studio to create a local debug key.
        goto :failed
    )
    if not exist "%APP_DIR%" mkdir "%APP_DIR%"
    (
        echo KEY_STORE=%DEBUG_KEYSTORE_GRADLE%
        echo KEY_STORE_PASSWORD=android
        echo KEY_STORE_ALIAS=androiddebugkey
        echo KEY_STORE_ALIAS_PASSWORD=android
    ) > "%SIGNING_FILE%"
    echo Signing the local Release APK with the Android debug key. Do not publish this APK.
)

where lime >nul 2>nul
if errorlevel 1 (
    echo ERROR: Lime was not found on PATH. Install Haxe/Lime or add lime.exe to PATH.
    goto :failed
)

set "PATH=%~dp0tools\android;%NDK_BIN%;%JAVA_HOME%\bin;%PATH%"

echo Building BetterPVZ for Android (release, ARM64)...
lime build android -release
if errorlevel 1 goto :failed

echo.
echo Build successful.
echo APK: %~dp0export\release\android\bin\app\build\outputs\apk\release\Pvz-release.apk
pause
exit /b 0

:failed
echo.
echo Android build failed. Check the errors above.
pause
exit /b 1
