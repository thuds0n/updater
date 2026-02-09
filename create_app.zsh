#!/bin/zsh

# =============================================================================
# Aquaria OSE Updater - App Bundler
# =============================================================================

# Configuration
APP_NAME="Aquaria Updater"
SOURCE_SCRIPT="src/aquaria_updater.zsh"
ICON_FILE="src/updater.icns"
PLIST_FILE="src/updater.plist"
OUTPUT_DIR="build"

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Building $APP_NAME.app...${NC}"

# Ensure source files exist
if [[ ! -f "$SOURCE_SCRIPT" ]]; then
    echo -e "${RED}Error: Source script not found at $SOURCE_SCRIPT${NC}"
    exit 1
fi

# Clean previous build
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create the .app bundle structure
APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Renamed to match the App name so macOS treats it as the entry point
cp "$SOURCE_SCRIPT" "$APP_PATH/Contents/MacOS/updater.zsh"
chmod +x "$APP_PATH/Contents/MacOS/updater.zsh"

# Copy the Metadata (Info.plist)
if [[ -f "$PLIST_FILE" ]]; then
    echo "Using Info.plist from $PLIST_FILE"
    cp "$PLIST_FILE" "$APP_PATH/Contents/Info.plist"
else
    echo -e "${RED}Warning: $PLIST_FILE not found. App will have no Info.plist file${NC}"
fi

# Copy the app icon (.icns)
if [[ -f "$ICON_FILE" ]]; then
    echo "Applying icon from $ICON_FILE"
    # We rename it to AppIcon.icns to match the Info.plist key
    cp "$ICON_FILE" "$APP_PATH/Contents/Resources/aquaria_updater.icns"
else
    echo -e "${RED}Warning: $ICON_FILE not found. App will have a generic icon.${NC}"
fi

# Finish message
echo -e "${GREEN}Success! App created at: $APP_PATH${NC}"
echo "------------------------------------------------------------"