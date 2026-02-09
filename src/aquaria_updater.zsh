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
    osascript -e "activate" -e "display dialog \"$msg\" buttons {\"OK\"} default button 1 with icon stop"
    exit 1
}

# =============================================================================
# 1. SETUP & SELECTION
# =============================================================================

# Select source
SOURCE_SELECTION=$(pick_source)
if [ -z "$SOURCE_SELECTION" ]; then exit 0; fi

# If the user selected a GOG wrapper, dive inside to the real app
if [ -d "$SOURCE_SELECTION/Contents/Resources/game/Aquaria.app" ]; then
    notify "GOG Version detected. Extracting internal game..."
    SOURCE_SELECTION="$SOURCE_SELECTION/Contents/Resources/game/Aquaria.app"
fi

SRC_ROOT="$SOURCE_SELECTION"
TARGET_APP="/Applications/AquariaOSE.app"

# Select AquariaOSE update branch (main or experimental)
BRANCH=$(pick_branch)
if [ "$BRANCH" = "CANCEL" ]; then exit 0; fi

# Config
REPO_URL="https://github.com/AquariaOSE/Aquaria/archive/refs/heads/$BRANCH.zip"
TEMP_DIR=$(mktemp -d)

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
notify "Copying original game files..."
if [ -d "$SRC_ROOT/Contents" ]; then
    cp -R "$SRC_ROOT/Contents" "$TARGET_APP/"
else
    # Fallback for Windows source (Attempt to build macOS structure)
    mkdir -p "$TARGET_APP/Contents/Resources"
    mkdir -p "$TARGET_APP/Contents/MacOS"
fi

# Copy across Info.plist
if [ -f "assets/aquariaOSE.plist" ]; then
    cp "assets/aquariaOSE.plist" "$TARGET_APP/Contents/Info.plist"
fi

# Copy custom icon
if [ -f "assets/aquariaOSE.icns" ]; then
    cp "assets/aquariaOSE.icns" "$TARGET_APP/Contents/Resources/aquariaOSE.icns"
fi

# Copy required game folders if they exist
for f in data gfx mus scripts sfx vox; do
    if [ -d "$SRC_ROOT/$f" ]; then cp -R "$SRC_ROOT/$f" "$TARGET_APP/"; fi
done

# =============================================================================
# ARM64 BINARY HANDLING
# =============================================================================

ARCH=$(uname -m)
BINARY_DEST="$TARGET_APP/Contents/MacOS/aquaria"

if [[ "$ARCH" == "arm64" ]]; then
    # Prompt for ARM64 binary
    # We use a loop or just a direct prompt.
    notify "Apple Silicon (arm64) detected."
    
    SELECTED_BINARY=$(pick_binary)
    
    if [ ! -z "$SELECTED_BINARY" ]; then
        notify "Installing ARM64 binary..."
        # Remove old binary (Intel)
        rm -f "$BINARY_DEST"
        # Copy new one
        cp "$SELECTED_BINARY" "$BINARY_DEST"
        chmod +x "$BINARY_DEST"
    else
        notify "No binary selected. Keeping original (Intel)."
    fi
fi

# =============================================================================
# 4. DOWNLOAD & MERGE GITHUB FILES
# =============================================================================

notify "Downloading $BRANCH branch..."

# Download
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

notify "Update Complete! AquariaOSE is ready in Applications."