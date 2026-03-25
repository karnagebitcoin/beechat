#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
LAUNCH_ROOT="$ROOT_DIR/.codex-launch"
APP_BUNDLE="$LAUNCH_ROOT/beechat.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$BUILD_DIR/bitchat"
FONTS_DIR="$ROOT_DIR/bitchat/Fonts"
STRINGS_CATALOG="$ROOT_DIR/bitchat/Localizable.xcstrings"
STRINGS_EXPORTER="$ROOT_DIR/scripts/export-xcstrings.rb"
ENTITLEMENTS_PLIST="$LAUNCH_ROOT/wrapper.entitlements"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift build --package-path "$ROOT_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/beechat"

if [[ -d "$FONTS_DIR" ]]; then
  mkdir -p "$RESOURCES_DIR/Fonts"
  cp "$FONTS_DIR"/*.ttf "$RESOURCES_DIR/Fonts/"
fi

find "$RESOURCES_DIR" -maxdepth 1 -type d -name '*.lproj' -exec rm -rf {} +

ruby "$STRINGS_EXPORTER" "$STRINGS_CATALOG" "$RESOURCES_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>beechat</string>
    <key>CFBundleExecutable</key>
    <string>beechat</string>
    <key>CFBundleIdentifier</key>
    <string>chat.beechat</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>beechat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.5.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>beechat uses Bluetooth to create a secure mesh network for chatting with nearby users.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>beechat uses Bluetooth to discover and connect with other beechat users nearby.</string>
    <key>NSCameraUsageDescription</key>
    <string>beechat uses the camera to scan QR codes to verify peers.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>beechat uses your approximate location to compute local geohash channels for optional public chats. Exact GPS is never shared.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>beechat uses the microphone to record voice notes that relay across the mesh.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>beechat lets you pick images from your photo library to share with nearby peers.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>beechat</string>
                <string>bitchat</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

cat > "$ENTITLEMENTS_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.assets.pictures.read-only</key>
    <true/>
    <key>com.apple.security.device.bluetooth</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.personal-information.location</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - --entitlements "$ENTITLEMENTS_PLIST" --timestamp=none "$APP_BUNDLE"

pkill -f "$APP_BUNDLE/Contents/MacOS/beechat" || true
open "$APP_BUNDLE"
