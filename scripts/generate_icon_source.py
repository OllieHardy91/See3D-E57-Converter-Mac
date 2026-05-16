"""Generate the 1024x1024 app-icon source PNG used by build.sh / CI to
produce the .icns. Output: assets/app_icon_source.png.

Design:
- White (-ish) background with a very subtle vertical gradient for depth.
- See3D wordmark from See3D Vector.png (the highest-res source) centred,
  ~62% of canvas width. Source is 1250x350 so it downscales cleanly.
- Soft drop shadow below the wordmark for a touch of dimensionality.
- No pre-rounded corners - macOS applies its squircle mask at render time.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent.parent
ASSETS = HERE / "assets"

SIZE        = 1024
LOGO_WIDTH  = int(SIZE * 0.62)
BG_TOP      = (255, 255, 255)
BG_BOTTOM   = (242, 246, 251)
SHADOW_OFFY = 18
SHADOW_BLUR = 28
SHADOW_OPACITY = 0.10


def linear_gradient(size: int, top: tuple[int, int, int],
                    bottom: tuple[int, int, int]) -> Image.Image:
    t = np.linspace(0.0, 1.0, size).reshape(-1, 1)
    r = (top[0] + (bottom[0] - top[0]) * t).astype(np.uint8)
    g = (top[1] + (bottom[1] - top[1]) * t).astype(np.uint8)
    b = (top[2] + (bottom[2] - top[2]) * t).astype(np.uint8)
    a = np.full_like(r, 255)
    column = np.stack([r, g, b, a], axis=-1)
    rgba = np.repeat(column, size, axis=1)
    return Image.fromarray(rgba, mode="RGBA")


def main() -> None:
    src_path = ASSETS / "See3D Vector.png"
    if not src_path.exists():
        raise SystemExit(f"Missing {src_path}")

    src = Image.open(src_path).convert("RGBA")

    # Background canvas with subtle vertical gradient
    canvas = linear_gradient(SIZE, BG_TOP, BG_BOTTOM)

    # Resize the wordmark preserving aspect ratio
    aspect = src.height / src.width
    logo_w = LOGO_WIDTH
    logo_h = int(logo_w * aspect)
    logo = src.resize((logo_w, logo_h), Image.LANCZOS)

    x = (SIZE - logo_w) // 2
    y = (SIZE - logo_h) // 2

    # Soft drop shadow
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste(logo, (x, y + SHADOW_OFFY), logo)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    shadow_arr = np.array(shadow)
    shadow_arr[..., 3] = (shadow_arr[..., 3].astype(np.float32) * SHADOW_OPACITY).astype(np.uint8)
    # Tint the shadow toward navy (matches the brand) instead of pure black
    shadow_arr[..., 0] = 0
    shadow_arr[..., 1] = 27
    shadow_arr[..., 2] = 135
    shadow = Image.fromarray(shadow_arr, mode="RGBA")

    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(logo, (x, y))

    out = ASSETS / "app_icon_source.png"
    canvas.save(out, "PNG", optimize=True)
    print(f"Wrote {out}  ({SIZE}x{SIZE})")

    # Also overwrite the 512px favicon used in the README preview so the
    # GitHub README shows the same clean white-bg icon, not the dark one.
    fav = canvas.resize((512, 512), Image.LANCZOS)
    fav.save(ASSETS / "favicon-light-512.png", "PNG", optimize=True)
    print(f"Wrote {ASSETS / 'favicon-light-512.png'}  (512x512)")


if __name__ == "__main__":
    main()
