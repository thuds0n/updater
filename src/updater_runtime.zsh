#!/bin/zsh

# =============================================================================
# Aquaria Open Source Edition (OSE) Updater for macOS
# Target: /Applications/AquariaOSE.app
# =============================================================================

# --- HELPER FUNCTIONS ---

pick_source() {
osascript -l JavaScript <<'EOD'
ObjC.import('AppKit');

const panel = $.NSOpenPanel.openPanel;
panel.setCanChooseFiles(true);
panel.setCanChooseDirectories(true);
panel.setAllowsMultipleSelection(false);
panel.setResolvesAliases(true);
panel.setTitle("Select Aquaria source");
panel.setMessage("Select Aquaria.app (Mac), Aquaria.exe (Windows), linux aquaria binary, or a game directory.");

const result = panel.runModal();
if (result === $.NSModalResponseOK) {
  const url = panel.URLs.objectAtIndex(0);
  console.log(ObjC.unwrap(url.path));
}
EOD
}

pick_binary() {
osascript <<EOD
    activate
    set validFile to choose file with prompt "Select your custom-built Aquaria binary:" of type {"public.unix-executable"}
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

detect_binary_archs() {
    local binary_path="$1"
    local archs=""
    local file_info=""

    if command -v lipo >/dev/null 2>&1; then
        archs=$(lipo -archs "$binary_path" 2>/dev/null)
    fi

    if [ -z "$archs" ] && command -v file >/dev/null 2>&1; then
        file_info=$(file -b "$binary_path" 2>/dev/null)
        [[ "$file_info" == *"i386"* ]] && archs="$archs i386"
        [[ "$file_info" == *"x86_64"* ]] && archs="$archs x86_64"
        [[ "$file_info" == *"arm64"* ]] && archs="$archs arm64"
        archs="${archs# }"
    fi

    echo "$archs"
}

validate_binary_archs() {
    local binary_path="$1"
    local archs
    local arch
    local supported=false

    archs=$(detect_binary_archs "$binary_path")
    if [ -z "$archs" ]; then
        show_error "Unable to detect binary architecture for: $binary_path"
    fi

    for arch in ${(z)archs}; do
        case "$arch" in
            i386|x86_64|arm64)
                supported=true
                ;;
        esac
    done

    if [ "$supported" != true ]; then
        show_error "Unsupported binary architecture: $archs. Expected one of i386, x86_64, or arm64."
    fi

    BINARY_ARCHS="$archs"
}

copy_sidecar_libraries() {
    local source_dir="$1"
    local dest_dir="$2"
    local lib_item

    for lib_item in "$source_dir"/*.dylib(N) "$source_dir"/*.framework(N) "$source_dir"/*.so(N); do
        cp -R "$lib_item" "$dest_dir/" || show_error "Failed to copy sidecar library: ${lib_item:t}"
    done
}

required_assets_exist() {
    local root_dir="$1"
    local f
    for f in data gfx mus scripts sfx vox; do
        if [ ! -d "$root_dir/$f" ]; then
            return 1
        fi
    done
    return 0
}

missing_required_assets() {
    local root_dir="$1"
    local missing=()
    local f
    for f in data gfx mus scripts sfx vox; do
        if [ ! -d "$root_dir/$f" ]; then
            missing+=("$f")
        fi
    done
    echo "${(j:, :)missing}"
}

# =============================================================================
# SETUP & SELECTION
# =============================================================================

# Set target app path
TARGET_APP="/Applications/AquariaOSE.app"
RUN_DIR=$(mktemp -d)
BUILD_APP="$RUN_DIR/AquariaOSE.app"
trap 'rm -rf "$RUN_DIR"' EXIT

# Locate the directory where the script is running (.app/Contents/MacOS)
SCRIPT_DIR="${0:A:h}"

# Locate the game assets (.app/Contents/Resources)
RESOURCES_DIR="$SCRIPT_DIR/../Resources"

# Locate the .app wrapper
APP_BUNDLE_DIR="${SCRIPT_DIR:h:h}"

# Directory of updated OSE assets and/or binary
UPDATED_ASSETS_DIR="$RESOURCES_DIR/files"

# Flag for whether this updater includes bundled updated game assets (release version)
IS_RELEASE_VERSION=false

# Select source
SOURCE_SELECTION=$(pick_source)
if [ -z "$SOURCE_SELECTION" ]; then
    show_error "No source installation was selected."
    exit 1
fi

# Determine directory of original game assets
ORIGINAL_ASSETS_DIR=""

# Accept a source directory and check if it already contains required assets
if required_assets_exist "$SOURCE_SELECTION"; then
    ORIGINAL_ASSETS_DIR="$SOURCE_SELECTION"

# Handling for .app selection
elif [[ "$SOURCE_SELECTION" == *.app ]]; then
    notify "Alternate Mac version detected"
    # For Mac Ambrosia version, also support Contents/Resources layout
    if required_assets_exist "$SOURCE_SELECTION/Contents/Resources"; then
        ORIGINAL_ASSETS_DIR="$SOURCE_SELECTION/Contents/Resources"
    # For wrapped macOS GOG version, support Contents/Resources/game/Aquaria.app layout
    elif required_assets_exist "$SOURCE_SELECTION/Contents/Resources/game/Aquaria.app"; then
        ORIGINAL_ASSETS_DIR="$SOURCE_SELECTION/Contents/Resources/game/Aquaria.app"
    else
        MISSING_ASSET_FOLDERS=$(missing_required_assets "$SOURCE_SELECTION")
        show_error "Required asset folders are missing from Mac .app.\nChecked:\n$SOURCE_SELECTION (missing: $MISSING_ASSET_FOLDERS)"
    fi

    # For executable selections (Windows .exe or Linux binary), use containing folder
elif [ -f "$SOURCE_SELECTION" ] && required_assets_exist "${SOURCE_SELECTION:h}"; then
    # Handling for Windows .exe
    if [[ "$SOURCE_SELECTION" == *.exe ]]; then
        notify "Windows executable detected. Using containing folder as source."
        ORIGINAL_ASSETS_DIR="${SOURCE_SELECTION:h}"
    # Handling for Linux executable (no extension)
    elif [[ "${SOURCE_SELECTION:t:l}" == "aquaria" ]]; then
        notify "Linux executable detected. Using containing folder as source."
        ORIGINAL_ASSETS_DIR="${SOURCE_SELECTION:h}"
    else
        show_error "Selected file does not appear to be a valid Aquaria executable."
    fi
fi

# Exit with error if no valid source of original game assets was found
if [ -z "$ORIGINAL_ASSETS_DIR" ]; then
    show_error "Invalid selection: $SOURCE_SELECTION\n"
    exit 0
fi

# =============================================================================
# APP BUILD
# =============================================================================

notify "Building AquariaOSE in staging area..."

# Create Target Directory
mkdir -p "$BUILD_APP"

# Build macOS app structure (binary/libs are installed separately)
mkdir -p "$BUILD_APP/Contents/Resources"
mkdir -p "$BUILD_APP/Contents/MacOS"
mkdir -p "$BUILD_APP/Contents/Frameworks"


# Copy original game asset folders and files from official installation
notify "Copying original game files..."
for f in data gfx mus scripts sfx vox _mods; do
    if [ -d "$ORIGINAL_ASSETS_DIR/$f" ]; then cp -R "$ORIGINAL_ASSETS_DIR/$f" "$BUILD_APP/"; fi
done

# Copy custom assets to updated app bundle
notify "Applying custom icon and metadata..."

# Copy Info.plist
if [[ -f "$RESOURCES_DIR/aquariaOSE.plist" ]]; then
    cp "$RESOURCES_DIR/aquariaOSE.plist" "$BUILD_APP/Contents/Info.plist"
else
    echo "Warning: aquariaOSE.plist not found in bundle."
fi

# Copy Icon
if [[ -f "$RESOURCES_DIR/aquariaOSE.icns" ]]; then
    mkdir -p "$BUILD_APP/Contents/Resources"
    cp "$RESOURCES_DIR/aquariaOSE.icns" "$BUILD_APP/Contents/Resources/aquariaOSE.icns"
else
    echo "Warning: aquariaOSE.icns not found in bundle."
fi


# =============================================================================
# DOWNLOAD & MERGE GITHUB FILES
# =============================================================================

# Check if bundled assets are present (release version)
if [ -d "$UPDATED_ASSETS_DIR" ]; then
    echo "Found bundled OSE assets inside Updater"
    IS_RELEASE_VERSION=true
else
    echo "No OSE assets bundled in updater. Manual selection required."
    IS_RELEASE_VERSION=false

    # Select AquariaOSE update branch (main or experimental)
    BRANCH=$(pick_branch)
    if [ "$BRANCH" = "CANCEL" ]; then exit 0; fi

    # AquariaOSE Git repo
    REPO_URL="https://github.com/AquariaOSE/Aquaria/archive/refs/heads/$BRANCH.zip"

    # Create a temporary directory for downloads and extraction
    TEMP_DIR="$RUN_DIR/download"
    mkdir -p "$TEMP_DIR"
    
    # Download repo zip from GitHub
    notify "Downloading $BRANCH branch..."
    if ! curl -fL --retry 3 --connect-timeout 10 -o "$TEMP_DIR/repo.zip" "$REPO_URL"; then
        show_error "Download failed. Check internet and selected branch."
    fi

    # Unzip
    if ! unzip -q "$TEMP_DIR/repo.zip" -d "$TEMP_DIR"; then
        show_error "Failed to extract downloaded update files."
    fi
    EXTRACTED_FOLDER="$TEMP_DIR/Aquaria-$BRANCH"

    if [ ! -d "$EXTRACTED_FOLDER/files" ]; then
        show_error "Downloaded branch has no 'files' folder."
    fi
    UPDATED_ASSETS_DIR="$EXTRACTED_FOLDER/files"
fi

# Merge updated OSE files (bundled assets or downloaded assets)
notify "Merging updated scripts and data..."

DEST_RESOURCES="$BUILD_APP/"

mkdir -p "$DEST_RESOURCES"

cp -R "$UPDATED_ASSETS_DIR/." "$DEST_RESOURCES/"

if [ "$IS_RELEASE_VERSION" = false ]; then
    # Cleanup download workspace now that merge is complete
    rm -rf "$TEMP_DIR"
fi

# =============================================================================
# BINARY HANDLING
# =============================================================================

BINARY_DEST="$BUILD_APP/Contents/MacOS/aquaria"
FRAMEWORKS_DEST="$BUILD_APP/Contents/Frameworks"
BUNDLED_BINARY="$RESOURCES_DIR/aquaria"
BINARY_ARCHS=""

mkdir -p "$FRAMEWORKS_DEST"

if [[ -f "$BUNDLED_BINARY" ]]; then
    echo "Using bundled binary..."
    validate_binary_archs "$BUNDLED_BINARY"
    cp "$BUNDLED_BINARY" "$BINARY_DEST"
    chmod +x "$BINARY_DEST"
    copy_sidecar_libraries "${BUNDLED_BINARY:h}" "$FRAMEWORKS_DEST"
else
    echo "No bundled binary found... Prompting for new binary"
    SELECTED_BINARY=$(pick_binary)
    
    if [ ! -z "$SELECTED_BINARY" ]; then
        notify "Installing selected binary..."
        validate_binary_archs "$SELECTED_BINARY"
        # Remove old binary (likely Intel)
        rm -f "$BINARY_DEST"
        # Copy new one
        cp "$SELECTED_BINARY" "$BINARY_DEST"
        chmod +x "$BINARY_DEST"
        copy_sidecar_libraries "${SELECTED_BINARY:h}" "$FRAMEWORKS_DEST"
    else
        show_error "No binary selected. A compatible i386, x86_64, or arm64 binary is required."
    fi
fi

# =============================================================================
# FINALISE
# =============================================================================

# Ensure binary executable (redundant check)
if [ -f "$BINARY_DEST" ]; then
    chmod +x "$BINARY_DEST"
fi

# Security Signing
notify "Signing app..."

if command -v xattr &> /dev/null; then
    xattr -cr "$BUILD_APP"
fi

if command -v codesign &> /dev/null; then
    codesign --force --deep -s - "$BUILD_APP" &> /dev/null
fi

# Deploy staged app
notify "Installing to Applications..."

if [ -d "$TARGET_APP" ]; then
    if ! rm -rf "$TARGET_APP"; then
        show_error "Could not remove existing app from /Applications."
    fi
fi

if ! mv "$BUILD_APP" "$TARGET_APP"; then
    show_error "Install failed while moving updated app to /Applications."
fi

# Success message
if [ -n "$BINARY_ARCHS" ]; then
    show_success "Update Complete! AquariaOSE is ready in your Applications folder.\nInstalled binary architectures: $BINARY_ARCHS"
else
    show_success "Update Complete! AquariaOSE is ready in your Applications folder."
fi
