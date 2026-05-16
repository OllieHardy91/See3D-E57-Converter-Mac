# See3D E57 Converter — macOS

A native macOS desktop app that turns a **Realsee Galois M2** capture
(LiDAR `.e57` + 360° equirectangular panoramas) into a COLMAP dataset
ready for **Gaussian Splatting** training in
[Brush](https://github.com/ArthurBrussee/brush), gsplat, or INRIA 3DGS.

```
.e57  +  panoramas/   ─►  See3D Converter  ─►  Colmap/  ─►  Splat trainer  ─►  .ply
```

> **Status:** macOS port in progress. Code parity with the
> [Windows app](https://github.com/OllieHardy91/See3D-E57-Converter-App) at
> the v1.1.0 fix level; build pipeline targets **Apple Silicon (arm64)**.
> No end-to-end conversion on real M2 data has been verified yet — please
> file issues if anything goes wrong.

## Download

Grab the latest `See3D-E57-Converter-macOS-arm64.zip` from
[Releases](https://github.com/OllieHardy91/See3D-E57-Converter-Mac/releases),
unzip, drag **See3D E57 Converter.app** into `~/Applications`.

### First launch (unsigned .app)

The bundle is unsigned, so macOS Gatekeeper will refuse to launch it via
double-click. Two ways to get past this:

**Easiest** — right-click → **Open** → click **Open** in the warning dialog.
macOS remembers your choice and subsequent launches work normally.

**Or** — strip the quarantine attribute once:

```bash
xattr -dr com.apple.quarantine "/Applications/See3D E57 Converter.app"
```

A signed/notarised build will come once the app stabilises and we have an
Apple Developer signing identity.

## What it does

Identical pipeline to the Windows app:

- Renders each 360° panorama into 4 or 6 cubemap face images.
- Reads scan poses from the `.e57` and writes one COLMAP camera entry per face.
- Subsamples the LiDAR point cloud into `points3D.txt` to seed splat training.
- Optionally re-projects LiDAR points through the generated poses and
  reports a mean colour-difference score (a healthy Realsee M2 capture
  scores **5–9**).

The COLMAP output runs unmodified in Brush, gsplat, or INRIA 3DGS.

## Quick use

1. Launch the app. Drag your `.e57` and panoramas folder onto the drop zone
   (or hit the Browse buttons).
2. Pick a Scene Preset (Small / Standard / Large / Huge or a custom point count).
3. Leave **Exclude floor & ceiling** ticked for indoor scenes.
4. Click **Convert**.
5. Open the resulting `Colmap/` folder in your splat trainer.

The Validate tab re-projects the LiDAR and shows a 3-panel overlay for each
of three representative scans, so you can sanity-check alignment visually.

## System requirements

- **macOS:** 12 Monterey or newer.
- **Architecture:** Apple Silicon (arm64) — M1/M2/M3/M4. Intel Macs aren't
  in the CI matrix yet; if you have an Intel Mac and want to help, please
  open an issue.
- **RAM:** 8 GB minimum, 16 GB recommended (cubemap workers run in parallel).
- **Disk:** 5–50 GB free in the output folder, depending on scan count.

The converter itself is CPU-only. **Training the splat afterwards** still
needs an NVIDIA GPU on a separate machine — no Mac GPU pipeline exists for
Brush yet.

## Building from source

```bash
git clone https://github.com/OllieHardy91/See3D-E57-Converter-Mac.git
cd See3D-E57-Converter-Mac
python3 -m pip install -r requirements.txt
python3 app.py                  # run from source
./build.sh                      # produce dist/See3D E57 Converter.app
```

Tested with Python 3.11 (Homebrew). `build.sh` requires `sips` and
`iconutil` — both ship with macOS.

## Differences from the Windows variant

The pipeline is byte-identical. The only changes are presentation:

| Aspect | Windows | macOS |
|---|---|---|
| Bundle format | `.exe` (PyInstaller `--onefile`) | `.app` (PyInstaller `--windowed`) |
| Icon source | `.ico` | `.icns` (generated from PNG via `iconutil`) |
| Title-bar font | Segoe UI Variable | SF Pro |
| Mono font (log) | Consolas | Menlo |
| Launcher | double-click `.exe` | double-click `.app` |
| Code-signing | unsigned, SmartScreen | unsigned, Gatekeeper |
| Build script | `build.bat` | `build.sh` |

## Files

```
app.py             ← CustomTkinter GUI (entry point)
converter_core.py  ← pye57 → COLMAP conversion pipeline (identical to Windows)
build.sh           ← PyInstaller build script (macOS)
assets/            ← PNG logos + favicon source
requirements.txt
.github/workflows/release.yml  ← CI build on macos-14 arm64 runner
```

## Calibration notes

This pipeline is **specifically calibrated** for the Realsee Galois M2:

- `yaw_offset = 0.0` (matches Realsee's azimuth frame)
- `camera_offset = (0, 0, 0)` (Realsee already aligns pano to LiDAR origin)
- Cubemap face size 4,000 px (matches the M2's native 16K × 8K panorama)
- 4-face mode routes floor / ceiling faces to a sibling `nadir_and_zenith/`
  folder so the splat trainer never sees Realsee's generative-fill artefacts

These were established empirically on two complete captures (a 223-scan
residential interior and a 45-scan commercial interior) using
re-projection-error testing. Don't change them without re-validating.

## Known macOS limitations

- **Drag-and-drop** uses `tkinterdnd2`, which carries a small native library.
  On Apple Silicon this is shipped as part of the `tkinterdnd2` wheel — if
  DnD isn't working, file an issue with `pip show tkinterdnd2` output.
- **Gatekeeper warning** on first launch (see "First launch" above).
- **Single-arch** for now — arm64 only. Intel build can be added once
  there's a confirmed user request.

## Credits

Built by [Shady Gmira / Ollie Hardy-Harris](https://see3d.uk) for the
See3D virtual-tour workflow. MIT licensed.
