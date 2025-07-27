# Eden Updater - Build Guide

## Quick Start

### Windows Distribution
```powershell
.\package_windows.ps1
```
Creates: `EdenUpdater_Windows_Portable.zip` (11MB)

### Linux Distribution  
```bash
./package_linux.sh
```
Creates: `EdenUpdater_Linux_Portable.tar.gz` (12MB)

### Android Distribution
```powershell
.\package_android.ps1  
```
Creates: `eden_updater_android/EdenUpdater.apk` (20MB)

## What Each Script Does

### Windows (`package_windows.ps1`)
1. Builds release version with `flutter build windows --release`
2. Copies all necessary files (exe, DLLs, data folder)
3. Creates portable folder structure
4. Generates README with usage instructions
5. Optionally creates ZIP file for distribution

### Linux (`package_linux.sh`)
1. Builds release version with `flutter build linux --release`
2. Copies entire bundle folder
3. Sets executable permissions
4. Creates launcher script for easy execution
5. Generates README and optionally creates tar.gz

### Android (`package_android.ps1`)
1. Builds release APK with `flutter build apk --release`
2. Copies APK to package folder
3. Renames to user-friendly name
4. Creates installation instructions
5. Provides APK information and distribution notes

## File Sizes

| Platform | Uncompressed | Compressed | Format |
|----------|-------------|------------|---------|
| Windows  | ~26 MB      | ~11 MB     | ZIP     |
| Linux    | ~30 MB      | ~12 MB     | tar.gz  |
| Android  | ~20 MB      | N/A        | APK     |

## Distribution

### Recommended Distribution Methods
- **GitHub Releases**: Attach compressed files to releases
- **Direct Download**: Host on web server
- **File Sharing**: Google Drive, Dropbox, etc.

### File Naming Convention
- `EdenUpdater_Windows_Portable.zip`
- `EdenUpdater_Linux_Portable.tar.gz`  
- `EdenUpdater.apk`

## Development Builds

For development and testing, you can still use raw Flutter commands:

```bash
# Development builds (not for distribution)
flutter build windows --release
flutter build linux --release
flutter build apk --release
```

But the packaging scripts are recommended even for testing as they:
- Include all necessary files
- Set proper permissions
- Create user-friendly structure
- Include documentation

## Prerequisites

### Windows
- Flutter SDK
- Visual Studio with C++ tools
- PowerShell (for packaging script)

### Linux  
- Flutter SDK
- Standard build tools (`build-essential`)
- Bash shell
- `bc` calculator (for size calculations)

### Android
- Flutter SDK
- Android SDK and NDK
- PowerShell (for packaging script)

## Troubleshooting

### Common Issues
- **Build failures**: Run `flutter doctor` to check setup
- **Missing files**: Ensure all dependencies are installed
- **Permission errors**: Run scripts with appropriate permissions

### Platform-Specific Issues
- **Windows**: Ensure Visual Studio C++ tools are installed
- **Linux**: Make sure `package_linux.sh` has execute permissions
- **Android**: Verify Android SDK path is configured correctly

## Automation

These scripts can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Package Windows
  run: .\package_windows.ps1
  
- name: Package Linux  
  run: ./package_linux.sh
  
- name: Package Android
  run: .\package_android.ps1
```

## Why No build_all Scripts?

The old `build_all.bat` and `build_all.sh` scripts were removed because:

- ❌ Only created raw build output
- ❌ Required manual file organization  
- ❌ No distribution packaging
- ❌ No user documentation
- ❌ Less professional output

The new packaging scripts are much better because:

- ✅ Create distribution-ready packages
- ✅ Include all necessary files automatically
- ✅ Generate user documentation
- ✅ Handle compression and optimization
- ✅ Professional, user-friendly output