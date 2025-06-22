#!/usr/bin/env bash

# Build all native components (Swift dylib + Rust N-API addon)
set -euo pipefail

echo "🔨  Building Apple On-Device AI library components …"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This library can only be built on macOS"
    exit 1
fi

# Require macOS 26+ (FoundationModels)
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if (( MACOS_MAJOR < 26 )); then
  echo "❌  Need macOS 26.0+ (FoundationModels). Current: $(sw_vers -productVersion)" >&2
  exit 1
fi

# Create build directory
mkdir -p build

# Build Swift dylib
echo "📦  Swift → build/libappleai.dylib"
swiftc \
  -O -whole-module-optimization \
  -emit-library -emit-module -module-name AppleOnDeviceAI \
  -framework Foundation -framework FoundationModels \
  -target arm64-apple-macos26.0 \
  -Xlinker -install_name -Xlinker @rpath/libappleai.dylib \
  -Xlinker -rpath -Xlinker @loader_path \
  src/apple-ai.swift \
  -o build/libappleai.dylib

echo "✅  Swift dylib built"

# Build Rust addon
echo "🦀  Cargo (release)"
pushd native >/dev/null
cargo build --release --quiet
popd >/dev/null

# Copy and rename the compiled addon to the build directory so Node/Bun can load it
ADDON_SRC="native/target/release/libapple_ai_napi.dylib"
ADDON_DST="build/apple_ai_napi.node"

if [[ -f "$ADDON_SRC" ]]; then
    cp "$ADDON_SRC" "$ADDON_DST"
    echo "📁 Native addon location: $ADDON_DST"
else
    echo "⚠️  Rust addon not found at $ADDON_SRC. Did the build fail?"
fi

echo "🎉  All components built successfully!" 