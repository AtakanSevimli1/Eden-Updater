#!/bin/bash

echo "Packaging Eden Updater for Linux..."

# Build the release version
echo "Building release version..."
flutter build linux --release
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Create package directory
PACKAGE_DIR="eden_updater_linux"
if [ -d "$PACKAGE_DIR" ]; then
    rm -rf "$PACKAGE_DIR"
fi
mkdir -p "$PACKAGE_DIR"

# Copy all necessary files
echo "Copying files..."
SOURCE_DIR="build/linux/x64/release/bundle"

cp -r "$SOURCE_DIR"/* "$PACKAGE_DIR/"

# Make the executable actually executable
chmod +x "$PACKAGE_DIR/eden_updater"

# Create a simple README
echo "Creating README..."
cat > "$PACKAGE_DIR/README.txt" << 'EOF'
Eden Updater - Linux Portable Version

To run Eden Updater:
1. Open terminal in this directory
2. Run: ./eden_updater

Or double-click eden_updater in your file manager (if it supports executable files)

Command line options:
  --auto-launch    : Automatically launch Eden after update
  --channel stable : Use stable channel (default)
  --channel nightly: Use nightly channel

This is a portable version - no installation required.
All files in this folder are needed for the application to work.

For desktop shortcuts, run the updater and enable "Create desktop shortcut"
in the settings. The shortcut will have auto-update functionality.
EOF

# Create a simple launcher script
echo "Creating launcher script..."
cat > "$PACKAGE_DIR/launch_eden_updater.sh" << 'EOF'
#!/bin/bash
# Eden Updater Launcher Script
# This script ensures the executable has proper permissions and launches the updater

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make sure the executable has execute permissions
chmod +x "$SCRIPT_DIR/eden_updater"

# Launch the updater with any provided arguments
"$SCRIPT_DIR/eden_updater" "$@"
EOF

chmod +x "$PACKAGE_DIR/launch_eden_updater.sh"

echo ""
echo "Package created successfully in $PACKAGE_DIR/"
echo "You can distribute this entire folder or create a tar.gz file from it."
echo ""

# Show files included
echo "Files included:"
find "$PACKAGE_DIR" -type f | sed 's|^'"$PACKAGE_DIR"'/|  |'

# Calculate total size
TOTAL_SIZE=$(du -sb "$PACKAGE_DIR" | cut -f1)
SIZE_IN_MB=$(echo "scale=2; $TOTAL_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "$(($TOTAL_SIZE / 1024 / 1024))")

echo ""
echo "Total size: ${SIZE_IN_MB} MB ($TOTAL_SIZE bytes)"

# Offer to create tar.gz
echo ""
read -p "Create tar.gz file? (y/n): " CREATE_TAR
if [[ "$CREATE_TAR" =~ ^[Yy]$ ]]; then
    TAR_NAME="EdenUpdater_Linux_Portable.tar.gz"
    echo "Creating tar.gz file..."
    
    if [ -f "$TAR_NAME" ]; then
        rm "$TAR_NAME"
    fi
    
    tar -czf "$TAR_NAME" -C "$PACKAGE_DIR" .
    
    if [ -f "$TAR_NAME" ]; then
        TAR_SIZE=$(stat -f%z "$TAR_NAME" 2>/dev/null || stat -c%s "$TAR_NAME" 2>/dev/null)
        TAR_SIZE_IN_MB=$(echo "scale=2; $TAR_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "$(($TAR_SIZE / 1024 / 1024))")
        echo "tar.gz file created: $TAR_NAME (${TAR_SIZE_IN_MB} MB)"
    fi
fi

echo ""
echo "Packaging complete!"