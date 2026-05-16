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
echo "[3/4] Generating .icns icon from 512px favicon..."
ICON_PNG="assets/favicon-dark-512.png"
ICONSET_DIR="build/See3D.iconset"
mkdir -p "$ICONSET_DIR"

# Standard .icns size set (most important: 16, 32, 128, 256, 512 plus @2x retina variants)
sips -z 16   16   "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
sips -z 32   32   "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
sips -z 64   64   "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
sips -z 256  256  "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256  256  "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
sips -z 512  512  "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512  512  "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
# Source is 512px; @2x of 512 (i.e. 1024) is upsampled - acceptable
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

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

echo
echo "-- BUILD COMPLETE --"
echo "App bundle: dist/See3D E57 Converter.app"
echo
echo "To distribute, zip the bundle:"
echo "  cd dist && zip -r 'See3D-E57-Converter-macOS.zip' 'See3D E57 Converter.app'"
echo
echo "First-launch note: the bundle is unsigned, so users need to right-click ->"
echo "Open the first time, or remove the quarantine attribute with:"
echo "  xattr -dr com.apple.quarantine 'See3D E57 Converter.app'"
