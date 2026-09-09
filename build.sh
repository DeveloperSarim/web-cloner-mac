#!/bin/bash
# Builds WebCloner.app as a universal binary (Intel + Apple Silicon).
set -e
cd "$(dirname "$0")"
APP="WebCloner.app"
MIN="13.0"

rm -rf "$APP" build && mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  echo "compiling $arch..."
  swiftc -O -parse-as-library -target $arch-apple-macos$MIN -o "build/$arch" Sources/Engine.swift Sources/UI.swift
done
lipo -create -output "$APP/Contents/MacOS/WebCloner" build/arm64 build/x86_64

echo "icon..."
swift Sources/makeicon.swift build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Web Cloner</string>
  <key>CFBundleDisplayName</key><string>Web Cloner</string>
  <key>CFBundleExecutable</key><string>WebCloner</string>
  <key>CFBundleIdentifier</key><string>local.webcloner</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>$MIN</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Opens Terminal to install Homebrew.</string>
</dict></plist>
PLIST

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep -s - "$APP" 2>/dev/null || true

# refresh the icon cache, otherwise Finder/Dock keep showing the old (or blank) icon
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

echo "installer..."
STAGE=build/dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f WebCloner.dmg
hdiutil create -volname "Web Cloner" -srcfolder "$STAGE" -ov -format UDZO -quiet WebCloner.dmg

rm -rf build
echo "built $APP + WebCloner.dmg"
lipo -archs "$APP/Contents/MacOS/WebCloner"
