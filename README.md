# Book-Translator ENG-RUS

macOS tools for **instant English → Russian translation** while reading (Apple Books, browsers, PDFs). Select text in any app; a floating popup shows the translation without leaving the page.

## Why this project

Reading English books on macOS often means constant context switching (Dictionary, browser tabs, copy-paste loops). Book-Translator automates that workflow with a lightweight Swift utility and a menu-bar-style popup—no API keys, no account setup.

## Features

- **TranslatePopup.app** — floating HUD window; watches text selection and translates automatically
- **translate-clipboard** — CLI helper (`bin/translate-clipboard`) for clipboard-based translation
- **Apple Books aware** — strips "Excerpt From …" / «Отрывок из книги …» citation boilerplate
- **No API key** — uses the public Google Translate `gtx` client endpoint (see Privacy)

## Requirements

- macOS 12+ (tested on Apple Silicon; Intel: rebuild from source)
- **Accessibility** permission (simulate ⌘C for selection capture)
- **Input Monitoring** (global mouse-up events in other apps)

Grant in **System Settings → Privacy & Security → Accessibility / Input Monitoring**, then add `TranslatePopup.app`.

## Quick start

```bash
git clone https://github.com/kundul02/Book-Translator-ENG-RUS.git
cd Book-Translator-ENG-RUS
open TranslatePopup.app
```

Prebuilt binaries in the repo are **arm64**. On Intel Macs, rebuild:

```bash
mkdir -p bin TranslatePopup.app/Contents/MacOS
swiftc src/translate-clipboard.swift -o bin/translate-clipboard
swiftc src/translate-clipboard.swift -o TranslatePopup.app/Contents/MacOS/TranslatePopup
```

CLI only:

```bash
./bin/translate-clipboard
```

Press **Esc** to hide the popup.

## Project structure

| Path | Description |
|------|-------------|
| `src/translate-clipboard.swift` | Single-file Swift source (app + CLI) |
| `TranslatePopup.app/` | Ready-to-run macOS app bundle (arm64) |
| `bin/translate-clipboard` | Prebuilt CLI binary (arm64) |

## Privacy

Selected text is sent to `translate.googleapis.com` for translation (same unofficial endpoint many browser extensions use). No analytics or third-party SDKs in this repo.

## Contributing

Issues and PRs welcome. Please do not commit API keys or personal paths.

## License

MIT — see [LICENSE](LICENSE).

## Author

Artem Sirchenko ([@kundul02](https://github.com/kundul02))
