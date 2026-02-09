# Aquaria OSE Updater for Mac

A small Zsh-based utility to automatically patch an Aquaria installation for macOS.

This tool uses the [Aquaria Open Source Edition repository](https://github.com/AquariaOSE/AquariaOSE).

## Overview

- Merges Open Source Edition assets into an existing installation.
- Supports macOS .app bundles, Windows folders, and Linux installs as a source.
- Prepares a clean AquariaOSE.app, suitable for modern macOS.

## Repository layout

```
├── create_app.zsh           # Script to bundle and create the Aquaria Updater.app
├── README.md
├── src/                     # Updater app files
│   ├── aquaria_updater.zsh  # Core update logic
│   ├── updater.icns
│   └── updater.plist
└── assets/                  # New OSE metadata and icon
    ├── aquariaOSEicon.icns
    └── aquariaOSE.plist
```

## Requirements

- macOS 10.15+ (32‑bit binaries are not supported)
- Zsh and standard macOS command-line tools
- Original Aquaria game data (this repo does **NOT** include game assets)
- An Aquaria executable/binary (required for ARM64 or when replacing the binary)

## Build

1. Open Terminal and navigate to the repository root
2. Make the bundle script executable and run it:

   ```bash
   chmod +x create_app.zsh
   ./create_app.zsh
   ```

3. The generated app will be created in `build/`

## Usage

1. Launch the `Aquaria Updater.app`
2. Select your source installation (i.e. `Aquaria.app`)
3. Choose Aquaria OSE update branch (*main* or *experimental*)
4. Optionally provide a new binary to replace exiting (required if using ARM64)
5. The updated `AquariaOSE.app` will be created in `/Applications`

## Architecture Support

| Architecture | Status | Notes |
| --- | ---: | --- |
| Apple Silicon (ARM64) | ✅ Tested | Fully supported with binary injection. |
| Intel 64-bit (x86_64) | ⚠️ Unknown | Should work via Rosetta or native Intel binaries; requires testing. |
| Intel 32-bit | ❌ Unsupported | Modern macOS (10.15+) does not support 32-bit binaries. |

## Notes

- This project requires original Aquaria assets.
- Use responsibly and follow license terms of the upstream project.