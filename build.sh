#!/usr/bin/env bash
# See3D E57 Converter - macOS .app build script.
# Run on a Mac with Python 3.10 or 3.11 installed (Homebrew Python works fine).
#
# Result: dist/See3D E57 Converter.app
set -euo pipefail
cd "$(dirname "$0")"

echo "-- See3D E57 Converter -- macOS PyInstaller build --"

# Pick Python: respect $PY env var, else use python3
PY="${PY:-python3}"
echo "Using Python: $($PY --version)"

echo
echo "[1/4] Cleaning previous build artefacts..."
rm -rf build dist

echo
echo "[2/4] Installing dependencies from requirements.txt..."
"$PY" -m pip install --upgrade pip --quiet
"$PY" -m pip install -r requirements.txt --quiet

echo
echo "[3/4] Generating .icns icon from assets/Final_Icon.png..."

ICONSET_DIR="build/See3D.iconset"
mkdir -p "$ICONSET_DIR"

# Crop tight to the squircle content before scaling — Final_Icon.png has
# ~230px transparent padding per side (content fills only ~62% of canvas).
# Without cropping, the Dock/Finder icon appears small and blurry.
SRC="$ICONSET_DIR/icon_cropped.png"
"$PY" -c "
from PIL import Image
img = Image.open('assets/Final_Icon.png').convert('RGBA')
bbox = img.getbbox()
pad = int((bbox[2] - bbox[0]) * 0.04)
img.crop((max(0,bbox[0]-pad), max(0,bbox[1]-pad), min(img.width,bbox[2]+pad), min(img.height,bbox[3]+pad))).save('$SRC')
"

# Final_Icon.png is the agreed app icon — used at every size so the Dock,
# Finder, Spotlight and Mission Control all show the same designed icon.
sips -z 16   16   "$SRC" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
sips -z 32   32   "$SRC" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   "$SRC" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
sips -z 64   64   "$SRC" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  "$SRC" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
sips -z 256  256  "$SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256  256  "$SRC" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
sips -z 512  512  "$SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512  512  "$SRC" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o assets/app_icon.icns
echo "  -> assets/app_icon.icns"

echo
echo "[4/4] Building .app with PyInstaller..."
"$PY" -m PyInstaller --windowed --noconfirm \
  --name "See3D E57 Converter" \
  --icon "assets/app_icon.icns" \
  --osx-bundle-identifier "uk.see3d.e57converter" \
  --add-data "assets:assets" \
  --hidden-import numpy \
  --hidden-import scipy \
  --hidden-import scipy.spatial \
  --hidden-import scipy.spatial.transform \
  --hidden-import scipy.spatial.transform._rotation_groups \
  --hidden-import cv2 \
  --hidden-import pye57 \
  --hidden-import tqdm \
  --hidden-import tqdm.auto \
  --hidden-import PIL \
  --hidden-import PIL.Image \
  --hidden-import customtkinter \
  --hidden-import tkinterdnd2 \
  --collect-data customtkinter \
  --collect-data tkinterdnd2 \
  --collect-data cv2 \
  --collect-binaries cv2 \
  --collect-binaries pye57 \
  --exclude-module torch \
  --exclude-module torchvision \
  --exclude-module torchaudio \
  --exclude-module tensorflow \
  --exclude-module jax \
  --exclude-module matplotlib \
  --exclude-module IPython \
  --exclude-module sklearn \
  --exclude-module pandas \
  --exclude-module pytest \
  --exclude-module notebook \
  app.py

APP="dist/See3D E57 Converter.app"
PLIST="$APP/Contents/Info.plist"

echo
echo "[5/5] Polishing Info.plist..."
VERSION=$("$PY" -c "import re; m=re.search(r'__version__\s*=\s*[\"\\']([^\"\\']+)', open('converter_core.py').read()); print(m.group(1) if m else '0.0.0')")
echo "  -> version = $VERSION"

set_or_add() {
  local key="$1" type="$2" value="$3"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$PLIST"
}
set_or_add LSMinimumSystemVersion        string "12.0"
set_or_add NSHighResolutionCapable       bool   true
set_or_add LSApplicationCategoryType     string "public.app-category.graphics-design"
set_or_add CFBundleShortVersionString    string "$VERSION"
set_or_add CFBundleVersion               string "$VERSION"
set_or_add CFBundleDisplayName           string "See3D E57 Converter"
set_or_add NSHumanReadableCopyright      string "Copyright (c) 2026 Shady Gmira / Ollie Hardy-Harris. MIT licensed."
plutil -lint "$PLIST" >/dev/null

echo
echo "Ad-hoc codesigning so the bundle launches without 'killed' on first run..."
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo
echo "-- BUILD COMPLETE --"
echo "App bundle: $APP"
echo
echo "To distribute, zip the bundle:"
echo "  cd dist && zip -r 'See3D-E57-Converter-macOS-v$VERSION.zip' 'See3D E57 Converter.app'"
echo
echo "First-launch note: the bundle is unsigned (ad-hoc only). Users need to"
echo "right-click -> Open the first time, or strip the quarantine attribute:"
echo "  xattr -dr com.apple.quarantine 'See3D E57 Converter.app'"
