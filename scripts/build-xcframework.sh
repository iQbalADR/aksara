#!/usr/bin/env bash
#
# Builds distributable XCFrameworks for Aksara + AksaraSwiftUI.
#
# Used to produce the binary artifacts consumed by Carthage (and by anyone who
# integrates an .xcframework manually). SwiftPM and CocoaPods build from source and
# do NOT need this.
#
# Usage (from the repo root):
#     ./scripts/build-xcframework.sh
#
# Output:  build/xcframeworks/<Module>.xcframework  (+ a matching .zip per module)
#
# Requires Xcode. By default it builds iOS device + iOS Simulator slices; uncomment
# entries in PLATFORMS below to add tvOS / watchOS / macOS.

set -euo pipefail

SCHEMES=("Aksara" "AksaraSwiftUI")

# label | xcodebuild destination
PLATFORMS=(
  "ios|generic/platform=iOS"
  "ios-sim|generic/platform=iOS Simulator"
  # "tvos|generic/platform=tvOS"
  # "tvos-sim|generic/platform=tvOS Simulator"
  # "watchos|generic/platform=watchOS"
  # "watchos-sim|generic/platform=watchOS Simulator"
  # "macos|generic/platform=macOS"
)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/xcframeworks"
rm -rf "$WORK"
mkdir -p "$WORK"

# Make SwiftPM emit dynamic .framework products (see Package.swift).
export AKSARA_DYNAMIC=1

for scheme in "${SCHEMES[@]}"; do
  frameworks=()
  for entry in "${PLATFORMS[@]}"; do
    label="${entry%%|*}"
    dest="${entry##*|}"
    archive="$WORK/$scheme-$label.xcarchive"
    dd="$WORK/dd-$scheme-$label"

    echo "▸ archiving $scheme ($label)"
    xcodebuild archive \
      -scheme "$scheme" \
      -destination "$dest" \
      -archivePath "$archive" \
      -derivedDataPath "$dd" \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      CODE_SIGNING_ALLOWED=NO \
      >/dev/null

    fw="$archive/Products/usr/local/lib/$scheme.framework"

    # SwiftPM archives leave the Swift module interface out of the .framework, so a
    # bare xcframework isn't importable. Copy the emitted .swiftmodule back in.
    module_src="$(find "$dd/Build/Intermediates.noindex/ArchiveIntermediates/$scheme/BuildProductsPath" \
      -type d -name "$scheme.swiftmodule" | head -1)"
    if [ -z "${module_src:-}" ]; then
      echo "  ✗ could not locate $scheme.swiftmodule" >&2
      exit 1
    fi
    if [ -d "$fw/Versions/A" ]; then           # versioned (macOS) bundle
      mkdir -p "$fw/Versions/A/Modules"
      cp -R "$module_src" "$fw/Versions/A/Modules/"
      ln -sfn "Versions/Current/Modules" "$fw/Modules"
    else                                       # shallow (iOS/tvOS/watchOS) bundle
      mkdir -p "$fw/Modules"
      cp -R "$module_src" "$fw/Modules/"
    fi

    frameworks+=(-framework "$fw")
  done

  out="$WORK/$scheme.xcframework"
  echo "▸ creating $scheme.xcframework"
  rm -rf "$out"
  xcodebuild -create-xcframework "${frameworks[@]}" -output "$out" >/dev/null

  (cd "$WORK" && zip -qr --symlinks "$scheme.xcframework.zip" "$(basename "$out")")
  echo "✓ $out (+ .zip)"
done

echo
echo "Done → $WORK"
echo "Attach the .zip files to a GitHub Release for Carthage 'binary' consumption."
