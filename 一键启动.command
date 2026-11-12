#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
    ""|--offline-lab|--build-only) ;;
    *) echo "用法：$0 [--offline-lab|--build-only]" >&2; exit 2 ;;
esac

swift build --product WalletDesktop
build_dir="$(swift build --show-bin-path)"
app="$PWD/玄金钱包.app"
stage="$(mktemp -d "$PWD/.build/wallet-app.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/玄金钱包.app"
contents="$bundle/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources" "$stage/WalletIcon.iconset"

install -m 755 "$build_dir/WalletDesktop" "$contents/MacOS/WalletDesktop"
for resource in WalletCore WalletDesktop; do
    ditto "$build_dir/SecureWallet_${resource}.bundle" \
        "$contents/Resources/SecureWallet_${resource}.bundle"
done

logo="Sources/WalletDesktop/Resources/WalletLogo.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$logo" --out "$stage/WalletIcon.iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$logo" \
        --out "$stage/WalletIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/WalletIcon.iconset" -o "$contents/Resources/WalletIcon.icns"

cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.securewallet.desktop.preview</string>
    <key>CFBundleName</key><string>玄金钱包</string>
    <key>CFBundleDisplayName</key><string>玄金钱包</string>
    <key>CFBundleExecutable</key><string>WalletDesktop</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.3</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>WalletIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"

if [[ -e "$app" ]]; then
    mv "$app" "$stage/previous.app"
fi
if ! mv "$bundle" "$app"; then
    if [[ -e "$stage/previous.app" ]]; then mv "$stage/previous.app" "$app"; fi
    exit 1
fi
case "${1:-}" in
    --build-only) ;;
    --offline-lab) open -n "$app" --args --offline-lab ;;
    *) open -n "$app" ;;
esac
