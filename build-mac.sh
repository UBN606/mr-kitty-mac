#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:-$source_dir/dist}"
app="$output_dir/Mr Kitty.app"
sdk="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$source_dir/Info.plist" "$app/Contents/Info.plist"
cp -R "$source_dir/Assets" "$app/Contents/Resources/Assets"

for arch in arm64 x86_64; do
  xcrun swiftc -parse-as-library -O -sdk "$sdk" -target "${arch}-apple-macos14.0" \
    "$source_dir/KittyApp.swift" -o "$output_dir/MrKitty-$arch"
done
xcrun lipo -create -output "$app/Contents/MacOS/MrKitty" \
  "$output_dir/MrKitty-arm64" "$output_dir/MrKitty-x86_64"
rm "$output_dir/MrKitty-arm64" "$output_dir/MrKitty-x86_64"
chmod 755 "$app/Contents/MacOS/MrKitty"
codesign --force --deep --sign - "$app"

/usr/bin/plutil -lint "$app/Contents/Info.plist"
test "$(find "$app/Contents/Resources/Assets" -name '*.png' -type f | wc -l | tr -d ' ')" = 22
xcrun lipo "$app/Contents/MacOS/MrKitty" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$app"
echo "Built and statically verified: $app"
