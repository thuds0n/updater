# Aquaria OSE Updater for Mac

A small script-based utility that upgrades an existing **Aquaria** installation to the **Open Source Edition (OSE)**, compatible with modern macOS.

This tool is a companion to the [Aquaria Open Source Edition repository](https://github.com/AquariaOSE/Aquaria).

## Overview
- The official macOS release of Aquaria is a legacy 32-bit application that hasn't been updated in over a decade
- Since macOS 10.15 (Catalina), it can no longer be played on modern Macs
- This tool streamlines the building process for Aquaria OSE, which is fully compatible with the latest versions of macOS

***Note:** If you have an Intel Mac with macOS 10.14 or earlier, you can still run the official Aquaria app natively (available for purchase on [GOG](https://www.gog.com/en/game/aquaria)).*

### Features
- Merges Open Source Edition files with an existing Aquaria installation
- Creates a clean standalone application without modifying the original installation
- Supports sourcing game data from macOS, Windows or Linux versions

### Architecture Support

| Mac Architecture | OSE Support | Notes | Official Version Support |
| --- | --- | --- | --- |
| Apple Silicon (arm64) | ✅ Supported | For Apple Silicon Macs with a compatible arm64 binary | ❌ Not Supported |
| Intel 64-bit (x86_64) | ✅ Supported | For 64-bit Intel Macs with a compatible x86_64 binary | ⚠️ Supported only for macOS <10.15 |
| Intel 32-bit (i386) | ✅ Supported | For 32-bit Intel Macs with a compatible i386 binary | ✅ Supported |
| PowerPC (ppc/ppc64) | ❌ Not Supported | Aquaria OSE does not target PowerPC | ⚠️ Supported only for legacy retail version |

## Getting Started
### Prerequisites
- Original Aquaria game data from an official release, which <u>**must**</u> be sourced from a legal purchase
- ***Only required for manual steps:*** A compatible Aquaria binary (refer to the [AquariaOSE repo](https://github.com/AquariaOSE/Aquaria) for compilation instructions)

### Quick Start

1) Download the latest updater app from the [Releases](https://github.com/AquariaOSE/Aquaria/releases) page
2) Run the updater app and select your existing Aquaria installation when prompted
3) Navigate to your `Applications` folder to find `AquariaOSE.app`
4) Launch and enjoy!

*If this fails, proceed with the [Developer Guide](#developer-guide) below*

## Developer Guide
- The following steps are for manually bundling the updater app and manually patching the game
- This allows you to select a custom-compiled binary and use OSE files from a specific branch
### Manual Build

1. Open Terminal and navigate to the repository root

   ```bash
   cd /path/to/updater
   ```

2. Make the bundle script executable and run it

   ```bash
   chmod +x build_updater_app.zsh
   ./build_updater_app.zsh
   ```

3. The updater app will be created in `build/`

### Manual Patching

1. Launch the `Aquaria Updater.app`
2. Select your source installation (i.e. `Aquaria.app`)
3. Choose your preferred Aquaria OSE update branch (*master* or *experimental*)
4. Select your new compatible Aquaria binary (compiled from the AquariaOSE repo)
5. Find `AquariaOSE.app` in your `Applications` folder

### Repository Layout

```
├── build_updater_app.zsh    # Script to bundle and create the updater app (`Aquaria Updater.app`)
├── README.md
├── src/                     # Updater app files
│   ├── updater_runtime.zsh  # Core update logic
│   ├── updater.icns
│   └── updater.plist
└── assets/                  # AquariaOSE app metadata and icon
    ├── aquariaOSE.icns
    └── aquariaOSE.plist
```
