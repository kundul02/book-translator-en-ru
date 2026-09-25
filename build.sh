#!/bin/zsh
# Builds bin/translate-clipboard and TranslatePopup.app from source.
#
# Signs with a stable local certificate ("TranslatePopup Local") when it exists,
# so the Accessibility permission survives rebuilds. Without it the app is
# ad-hoc signed and macOS asks for the permission again after every build.
set -euo pipefail
cd "$(dirname "$0")"

SRC=src/translate-clipboard.swift
APP=TranslatePopup.app
BUNDLE_ID=com.antigravity.TranslatePopup
IDENTITY="TranslatePopup Local"

mkdir -p bin "$APP/Contents/MacOS"
swiftc -O "$SRC" -o bin/translate-clipboard
swiftc -O "$SRC" -o "$APP/Contents/MacOS/TranslatePopup"

if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    SIGN="$IDENTITY"
else
    echo "warning: certificate \"$IDENTITY\" not found, using ad-hoc signature" >&2
    SIGN=-
fi
codesign --force --sign "$SIGN" --identifier "$BUNDLE_ID" "$APP"
codesign --force --sign "$SIGN" --identifier "$BUNDLE_ID.cli" bin/translate-clipboard
codesign --verify --strict "$APP"
echo "Built and signed with: $SIGN"

# Keep the installed copy in sync (the same signature keeps its Accessibility permission)
if [[ -d /Applications/$APP ]]; then
    ditto "$APP" "/Applications/$APP"
    echo "Updated /Applications/$APP"
fi
