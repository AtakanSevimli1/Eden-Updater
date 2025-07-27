Write-Host "Packaging Eden Updater for Windows..." -ForegroundColor Green

# Build the release version
Write-Host "Building release version..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Create package directory
$packageDir = "eden_updater"
if (Test-Path $packageDir) {
    Remove-Item $packageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

# Copy all necessary files
Write-Host "Copying files..." -ForegroundColor Yellow
$sourceDir = "build\windows\x64\runner\Release"

Copy-Item "$sourceDir\eden_updater.exe" $packageDir
Copy-Item "$sourceDir\flutter_windows.dll" $packageDir
Copy-Item "$sourceDir\url_launcher_windows_plugin.dll" $packageDir
Copy-Item "$sourceDir\data" "$packageDir\data" -Recurse

# Create a simple README
Write-Host "Creating README..." -ForegroundColor Yellow
$readmeContent = @"
Eden Updater

To run Eden Updater:
1. Double-click eden_updater.exe

Command line options:
  --auto-launch    : Automatically launch Eden after update
  --channel stable : Use stable channel (default)
  --channel nightly: Use nightly channel

This is a portable version - no installation required.
All files in this folder are needed for the application to work.

For desktop shortcuts, run the updater and enable "Create desktop shortcut"
in the settings. The shortcut will have auto-update functionality.
"@

$readmeContent | Out-File "$packageDir\README.txt" -Encoding UTF8

Write-Host ""
Write-Host "Package created successfully in $packageDir\" -ForegroundColor Green
Write-Host "You can distribute this entire folder or create a ZIP file from it." -ForegroundColor Cyan
Write-Host ""

# Show files included
Write-Host "Files included:" -ForegroundColor Yellow
Get-ChildItem $packageDir -Recurse | ForEach-Object { 
    $relativePath = $_.FullName.Replace((Get-Location).Path + "\$packageDir\", "")
    Write-Host "  $relativePath"
}

# Calculate total size
$totalSize = (Get-ChildItem $packageDir -Recurse | Measure-Object -Property Length -Sum).Sum
$sizeInMB = [math]::Round($totalSize / 1MB, 2)
Write-Host ""
Write-Host "Total size: $sizeInMB MB ($totalSize bytes)" -ForegroundColor Cyan

# Offer to create ZIP
Write-Host ""
$createZip = Read-Host "Create ZIP file? (y/n)"
if ($createZip -eq 'y' -or $createZip -eq 'Y') {
    $zipName = "EdenUpdater_Windows.zip"
    Write-Host "Creating ZIP file..." -ForegroundColor Yellow
    
    if (Test-Path $zipName) {
        Remove-Item $zipName -Force
    }
    
    Compress-Archive -Path "$packageDir\*" -DestinationPath $zipName
    
    if (Test-Path $zipName) {
        $zipSize = (Get-Item $zipName).Length
        $zipSizeInMB = [math]::Round($zipSize / 1MB, 2)
        Write-Host "ZIP file created: $zipName ($zipSizeInMB MB)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Packaging complete!" -ForegroundColor Green