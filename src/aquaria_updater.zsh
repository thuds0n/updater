#!/bin/zsh

# =============================================================================
# Aquaria OSE Updater
# Target: /Applications/AquariaOSE.app
# =============================================================================

# --- HELPER FUNCTIONS ---

pick_source() {
osascript <<EOD
    activate
    set validFile to choose file with prompt "Select your existing Aquaria game:\n(Select 'Aquaria.app' for Mac, or 'Aquaria.exe' for Windows)" of type {"com.apple.application-bundle", "public.unix-executable", "com.microsoft.windows-executable"}
    return POSIX path of validFile
EOD
}

pick_binary() {
osascript <<EOD
    activate
    set validFile to choose file with prompt "Select your custom ARM64 Aquaria Binary:" of type {"public.unix-executable"}
    return POSIX path of validFile
EOD
}

pick_branch() {
osascript <<EOD
    activate
    set branchList to {"main", "experimental"}
    set chosenBranch to choose from list branchList with prompt "Which AquariaOSE branch do you want to use?" default items "main"
    if chosenBranch is false then return "CANCEL"
    return item 1 of chosenBranch
EOD
}

notify() {
    osascript -e "display notification \"$1\" with title \"Aquaria Updater\""
}

show_error() {
    local msg="${1//\"/\\\"}"
    # Re-enable output for the error dialog so it actually shows up
    exec > /dev/tty 2>/dev/null 
    osascript -e "activate" -e "display dialog \"❌ Error: $msg\" buttons {\"OK\"} default button 1 with icon stop"
    exit 1
}

show_success() {
    local msg="${1//\"/\\\"}"
    # Re-enable output briefly for success message if needed
    osascript -e "activate" -e "display dialog \"✅ Update Complete!\n\n$msg\" buttons {\"OK\"} default button 1 with icon note"
}

# =============================================================================
# 1. SETUP & SELECTION
# =============================================================================

# Set target app path
TARGET_APP="/Applications/AquariaOSE.app"

# Locate the directory where the script is running (.app/Contents/MacOS)
SCRIPT_DIR="${0:A:h}"

# Locate the game assets (.app/Contents/Resources)
RESOURCES_DIR="$SCRIPT_DIR/../Resources"

# Locate the .app wrapper
APP_BUNDLE_DIR="${SCRIPT_PATH:h:h:h}"

# Locate the bundled update files
UPDATE_FILES="$RESOURCES_DIR/files"

# Check for bundled assets (Installer Mode)
if [ -d "$RESOURCES_DIR/files" ]; then
    echo "Found bundled assets inside Updater"
    SRC_ROOT="$APP_BUNDLE_DIR"
    IS_BUNDLED_INSTALLER=true
    UPDATE_FILES="$RESOURCES_DIR/files"
else
    echo "No bundled assets found. Manual selection required."
    IS_BUNDLED_INSTALLER=false
    
    # Select source
    SOURCE_SELECTION=$(pick_source)
    if [ -z "$SOURCE_SELECTION" ]; then exit 0; fi

    # If the user selected a GOG wrapper, dive inside to the real app
    if [ -d "$SOURCE_SELECTION/Contents/Resources/game/Aquaria.app" ]; then
        notify "GOG Version detected. Extracting internal game..."
        SOURCE_SELECTION="$SOURCE_SELECTION/Contents/Resources/game/Aquaria.app"
    fi

    SRC_ROOT="$SOURCE_SELECTION"
    UPDATE_FILES="$SRC_ROOT"

fi

if [ "$IS_BUNDLED_INSTALLER" = false ]; then
    # Select AquariaOSE update branch (main or experimental)
    BRANCH=$(pick_branch)
    if [ "$BRANCH" = "CANCEL" ]; then exit 0; fi

    # AquariaOSE Git repo
    REPO_URL="https://github.com/AquariaOSE/Aquaria/archive/refs/heads/$BRANCH.zip"
fi

# =============================================================================
# 2. CONSTRUCTION
# =============================================================================

notify "Building AquariaOSE in Applications folder..."

# Clean old version
if [ -d "$TARGET_APP" ]; then
    rm -rf "$TARGET_APP"
fi

# Create Target Directory
mkdir -p "$TARGET_APP"

# Copy Contents directory
notify "Copying game files..."
if [ -d "$SRC_ROOT/Contents" ] && [ "$IS_BUNDLED_INSTALLER" = false ]; then
    cp -R "$SRC_ROOT/Contents" "$TARGET_APP/"
else
    # Build macOS structure if data bundled or Windows source
    mkdir -p "$TARGET_APP/Contents/Resources"
    mkdir -p "$TARGET_APP/Contents/MacOS"
fi

# Copy required game folders if they exist
for f in data gfx mus scripts sfx vox _mods; do
    if [ -d "$UPDATE_FILES/$f" ]; then cp -R "$UPDATE_FILES/$f" "$TARGET_APP/"; fi
done

# Copy custom assets to updated app bundle
notify "Applying custom icon and metadata..."

# Copy Info.plist
if [[ -f "$RESOURCES_DIR/aquariaOSE.plist" ]]; then
    cp "$RESOURCES_DIR/aquariaOSE.plist" "$TARGET_APP/Contents/Info.plist"
else
    echo "Warning: aquariaOSE.plist not found in bundle."
fi

# Copy Icon
if [[ -f "$RESOURCES_DIR/aquariaOSE.icns" ]]; then
    mkdir -p "$TARGET_APP/Contents/Resources"
    cp "$RESOURCES_DIR/aquariaOSE.icns" "$TARGET_APP/Contents/Resources/aquariaOSE.icns"
else
    echo "Warning: aquariaOSE.icns not found in bundle."
fi

# =============================================================================
# BINARY HANDLING
# =============================================================================

BINARY_DEST="$TARGET_APP/Contents/MacOS/aquaria"
BUNDLED_BINARY="$RESOURCES_DIR/aquaria"

if [[ -f "$BUNDLED_BINARY" ]]; then
    echo "Using bundled binary..."
    cp "$BUNDLED_BINARY" "$BINARY_DEST"
    chmod +x "$BINARY_DEST"
else
    echo "No bundled binary found... Prompting for new binary"
    SELECTED_BINARY=$(pick_binary)
    
    if [ ! -z "$SELECTED_BINARY" ]; then
        notify "Installing selected binary..."
        # Remove old binary (likely Intel)
        rm -f "$BINARY_DEST"
        # Copy new one
        cp "$SELECTED_BINARY" "$BINARY_DEST"
        chmod +x "$BINARY_DEST"
    else
        notify "No binary selected... Keeping original"
    fi
fi

## TODO: Automatic arm64 binary compilation 
# ARCH=$(uname -m)
# if [[ "$ARCH" == "arm64" ]]; then
#     # Prompt for ARM64 binary
#     notify "Apple Silicon (arm64) detected."
# fi

# =============================================================================
# 4. DOWNLOAD & MERGE GITHUB FILES
# =============================================================================

if [ "$IS_BUNDLED_INSTALLER" = false ]; then
    # Create a temporary directory for downloads and extraction
    TEMP_DIR=$(mktemp -d)

    # Set a trap so the temp folder is deleted even if the user quits or the script errors out
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    # Download repo zip from GitHub
    notify "Downloading $BRANCH branch..."
    curl -L -o "$TEMP_DIR/repo.zip" "$REPO_URL"


    if [ ! -f "$TEMP_DIR/repo.zip" ]; then
        show_error "Download failed. Check internet."
    fi

    # Unzip
    unzip -q "$TEMP_DIR/repo.zip" -d "$TEMP_DIR"
    EXTRACTED_FOLDER="$TEMP_DIR/Aquaria-$BRANCH"

    if [ ! -d "$EXTRACTED_FOLDER/files" ]; then
        show_error "Downloaded branch has no 'files' folder."
    fi

    notify "Merging updated scripts and data..."

    # Merge Git Files
    DEST_RESOURCES="$TARGET_APP/"

    # Ensure destination exists (it should from Step 2a)
    mkdir -p "$DEST_RESOURCES"

    # Merge
    cp -R "$EXTRACTED_FOLDER/files/" "$DEST_RESOURCES/"

    # Cleanup
    rm -rf "$TEMP_DIR"
fi

# =============================================================================
# 5. FINALIZE
# =============================================================================

# Ensure binary executable (redundant check)
if [ -f "$BINARY_DEST" ]; then
    chmod +x "$BINARY_DEST"
fi

# Security Signing
notify "Signing app..."

if command -v xattr &> /dev/null; then
    xattr -cr "$TARGET_APP"
fi

if command -v codesign &> /dev/null; then
    codesign --force --deep -s - "$TARGET_APP" &> /dev/null
fi

# Success message
show_success "Update Complete! AquariaOSE is ready in your Applications folder."