@echo off
echo Building Eden Updater for all platforms...

echo.
echo Building for Windows...
flutter build windows --release
if %errorlevel% neq 0 (
    echo Windows build failed!
    exit /b 1
)

echo.
echo Building for Linux...
flutter build linux --release
if %errorlevel% neq 0 (
    echo Linux build failed!
    exit /b 1
)

echo.
echo Building for Android...
flutter build apk --release
if %errorlevel% neq 0 (
    echo Android build failed!
    exit /b 1
)

echo.
echo Build complete! Check the build/ directory for binaries.
echo.
echo Windows: build\windows\x64\runner\Release\
echo Linux: build\linux\x64\release\bundle\
echo Android: build\app\outputs\flutter-apk\app-release.apk
pause