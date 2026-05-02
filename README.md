# Book-Translator ENG-RUS

A powerful set of tools for instant translation on macOS.

## Features
- **TranslatePopup**: A macOS application for quick text translation.
- **Clipboard Translator**: A Swift-based utility to translate content directly from your clipboard.
- **Automation Scripts**: The `scripts/` folder is reserved for ZSH helpers (add your own).

## Project Structure
- `src/`: Source code for the translation utilities.
- `scripts/`: Optional automation scripts (not shipped in the repo by default).
- `bin/`: Compiled binaries (ignored by Git, but generated on build).
- `TranslatePopup.app`: App bundle metadata (`Info.plist`). Build the executable locally and place it in `TranslatePopup.app/Contents/MacOS/` (the binary path is gitignored).

## Installation
To compile the clipboard translator:
```bash
mkdir -p bin
swiftc src/translate-clipboard.swift -o bin/translate-clipboard
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
