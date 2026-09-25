# Book-Translator ENG-RUS

macOS tools for **instant English → Russian translation** while reading (Apple Books, browsers, PDFs). Select text in any app; a floating popup shows the translation without leaving the page.

## Why this project

Reading English books on macOS often means constant context switching (Dictionary, browser tabs, copy-paste loops). Book-Translator automates that workflow with a lightweight Swift utility and a menu-bar-style popup—no API keys, no account setup.

## Features

- **TranslatePopup.app** — floating HUD window; watches text selection and translates automatically
- **translate-clipboard** — CLI helper (`bin/translate-clipboard`) for clipboard-based translation
- **Apple Books aware** — strips "Excerpt From …" / «Отрывок из книги …» citation boilerplate and auto-closes the Books highlight menu after a selection (hold **⌥ Option** while selecting to keep it)
- **Clipboard-safe** — your clipboard is restored after the selection is copied (all content types)
- **Smart triggering** — only drags, double/triple clicks and shift-clicks count as selections
- **Read aloud** — 🔊 button speaks the original English text; uses the best installed English voice (download Premium/Enhanced voices in System Settings → Accessibility → Spoken Content → System Voice → Manage Voices)
- **No API key** — uses the public Google Translate `gtx` client endpoint (see Privacy)

## Requirements

- macOS 12+ (tested on Apple Silicon; Intel: rebuild from source)
- **Accessibility** permission (simulate ⌘C for selection capture)
- **Input Monitoring** (global mouse-up events in other apps)

Grant in **System Settings → Privacy & Security → Accessibility / Input Monitoring**, then add `TranslatePopup.app`. The app picks up the permission automatically once granted, no restart needed.

## Quick start

```bash
git clone https://github.com/kundul02/Book-Translator-ENG-RUS.git
cd Book-Translator-ENG-RUS
open TranslatePopup.app
```

Prebuilt binaries in the repo are **arm64**. On Intel Macs (or after editing the source), rebuild:

```bash
./build.sh
```

The script builds both binaries and signs them. If a code-signing certificate named
**"TranslatePopup Local"** is in your keychain, it is used, so the Accessibility permission
survives rebuilds; otherwise the build is ad-hoc signed and macOS asks for the permission
again after each rebuild (remove the old TranslatePopup entry and re-add it).

CLI only:

```bash
./bin/translate-clipboard
```

To launch it like any other app (Spotlight, Launchpad, Dock), install it once:

```bash
ditto TranslatePopup.app /Applications/TranslatePopup.app
```

The app shows in the Dock while running (right-click → Options → Keep in Dock to pin it).

Press **Esc** to hide the popup; clicking the Dock icon or launching the app again brings it back. **+** / **−** change the font size.

## Project structure

| Path | Description |
|------|-------------|
| `src/translate-clipboard.swift` | Single-file Swift source (app + CLI) |
| `TranslatePopup.app/` | Ready-to-run macOS app bundle (arm64) |
| `bin/translate-clipboard` | Prebuilt CLI binary (arm64) |
| `build.sh` | Builds and signs both binaries; refreshes `/Applications/TranslatePopup.app` if installed |
| `tools/make-icon.swift` | Renders the app icon (`swift tools/make-icon.swift`) |

## Privacy

Selected text is sent to `translate.googleapis.com` for translation (same unofficial endpoint many browser extensions use). No analytics or third-party SDKs in this repo.

## Contributing

Issues and PRs welcome. Please do not commit API keys or personal paths.

## License

MIT — see [LICENSE](LICENSE).

## Author

Artem Sirchenko ([@kundul02](https://github.com/kundul02))
