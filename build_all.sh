#!/bin/bash

echo "Building Eden Updater for all platforms..."

echo ""
echo "Building for Windows..."
flutter build windows --release
if [ $? -ne 0 ]; then
    echo "Windows build failed!"
    exit 1
fi

echo ""
echo "Building for Linux..."
flutter build linux --release
if [ $? -ne 0 ]; then
    echo "Linux build failed!"
    exit 1
fi

echo ""
echo "Building for Android..."
flutter build apk --release
if [ $? -ne 0 ]; then
    echo "Android build failed!"
    exit 1
fi

echo ""
echo "Building for macOS..."
flutter build macos --release
if [ $? -ne 0 ]; then
    echo "macOS build failed (this is expected on non-Mac systems)"
fi

echo ""
echo "Build complete! Check the build/ directory for binaries."
echo ""
echo "Windows: build/windows/x64/runner/Release/"
echo "Linux: build/linux/x64/release/bundle/"
echo "Android: build/app/outputs/flutter-apk/app-release.apk"
echo "macOS: build/macos/Build/Products/Release/"