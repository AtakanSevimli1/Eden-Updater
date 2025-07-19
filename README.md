# Eden Updater

A cross-platform GUI updater for the Eden emulator, built with Flutter. This updater provides an easy way to keep your Eden emulator installation up to date across Windows, Linux, Android.

## Features

- 🎮 Clean, modern UI inspired by the yuzu updater
- 🔄 Automatic update checking from GitHub releases
- 📱 Cross-platform support (Windows, Linux, Android, macOS)
- 📦 Automatic download and installation of updates
- 🚀 Launch Eden directly from the updater
- 🌐 Quick access to the Eden GitHub repository

## Screenshots

The updater features a dark theme with a clean, intuitive interface that makes updating Eden effortless.

## Building from Source

### Prerequisites

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Ensure you have the required platform tools:
   - **Windows**: Visual Studio with C++ tools
   - **Linux**: Standard build tools (`build-essential`)
   - **Android**: Android SDK and NDK

### Quick Build

Run the build script for your platform:

**Windows:**
```cmd
build_all.bat
```

**Linux:**
```bash
./build_all.sh
```

### Manual Building

For individual platforms:

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# Android
flutter build apk --release
```

## Output Locations

After building, find your binaries here:

- **Windows**: `build/windows/x64/runner/Release/eden_updater.exe`
- **Linux**: `build/linux/x64/release/bundle/` (entire folder)
- **Android**: `build/app/outputs/flutter-apk/app-release.apk`

## Configuration

The updater automatically:
- Downloads Eden to your Documents/Eden folder
- Stores version information locally
- Handles platform-specific executable formats

You can customize the installation path through the app's settings (feature coming soon).

## GitHub Integration

The updater fetches releases from these repositories:
- **Stable releases**: https://github.com/eden-emulator/Releases/releases
- **Nightly releases**: https://github.com/pflyly/eden-nightly/releases

The updater automatically:
1. Detects platform-specific assets (Windows .exe/.zip, Linux .tar.gz, Android .apk)
2. Follows standard GitHub release conventions
3. Allows switching between stable and nightly channels

## Development

### Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   └── update_info.dart   # Update data model
├── screens/
│   └── updater_screen.dart # Main UI screen
└── services/
    └── update_service.dart # Update logic and GitHub API
```

### Running in Development

```bash
flutter run -d windows  # or linux, android
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

## License

This project is open source. Please check the LICENSE file for details.

## Support

For issues or questions:
- Open an issue on the Eden GitHub repository
- Check the Flutter documentation for platform-specific build issues
- Ensure all dependencies are properly installed for your target platform
