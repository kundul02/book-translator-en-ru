# Book-Translator ENG-RUS

A powerful set of tools for instant translation on macOS.

## Features
- **TranslatePopup**: A macOS application for quick text translation.
- **Clipboard Translator**: A Swift-based utility to translate content directly from your clipboard.
- **Automation Scripts**: ZSH scripts to integrate translation into your workflow.

## Project Structure
- `src/`: Source code for the translation utilities.
- `scripts/`: Helper scripts for automation and workflow integration.
- `bin/`: Compiled binaries (ignored by Git, but generated on build).
- `TranslatePopup.app`: The compiled macOS application.

## Installation
To compile the clipboard translator:
```bash
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
