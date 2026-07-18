#!/bin/zsh
# QuickFind.app 번들 빌드 스크립트
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift build (release)"
swift build -c release

APP="build/QuickFind.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/QuickFind "$APP/Contents/MacOS/QuickFind"
cp packaging/Info.plist "$APP/Contents/Info.plist"

if [[ ! -f packaging/AppIcon.icns ]]; then
    echo "==> generating app icon"
    swift scripts/make_icon.swift packaging
    iconutil -c icns packaging/AppIcon.iconset -o packaging/AppIcon.icns
    rm -rf packaging/AppIcon.iconset
fi
cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> codesign (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> done: $PWD/$APP"
