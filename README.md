# Book-Translator ENG-RUS

A powerful set of tools for instant translation on macOS.

## Features
- **TranslatePopup**: A macOS application for quick text translation.
- **Clipboard Translator**: A Swift-based utility to translate content directly from your clipboard.
- **Automation Scripts**: The `scripts/` folder is reserved for ZSH helpers (add your own).

## Project Structure
- `src/`: Source code for the translation utilities.
- `scripts/`: Optional automation scripts (not shipped in the repo by default).
- `bin/`: Prebuilt CLI binary (`translate-clipboard`) for quick use after clone.
- `TranslatePopup.app`: Ready-to-run macOS app bundle. Binaries in the repo are **Apple Silicon (arm64)**; on Intel Macs, rebuild from `src/translate-clipboard.swift`.

## Installation
After cloning, you can run the bundled builds as-is (arm64):

- Double-click **`TranslatePopup.app`** or run `./bin/translate-clipboard` from the repo root.

To recompile from source (any Mac):

```bash
mkdir -p bin TranslatePopup.app/Contents/MacOS
swiftc src/translate-clipboard.swift -o bin/translate-clipboard
swiftc src/translate-clipboard.swift -o TranslatePopup.app/Contents/MacOS/TranslatePopup
```

## Usage
### Clipboard Translation
```bash
./bin/translate-clipboard
```

### Automation
Check the `scripts/` directory for utility scripts.

---
Developed by Artem Sirchenko.
