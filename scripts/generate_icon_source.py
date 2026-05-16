"""Generate the app-icon source PNGs used by build.sh / CI to produce the
.icns (macOS) and .ico (Windows).

Outputs:
- assets/app_icon_source.png       1024x1024  wordmark variant (128-1024)
- assets/app_icon_mono_source.png  1024x1024  "3D" monogram variant (16/32/64)
- assets/favicon-light-512.png     512x512    README preview / Tk window icon

Design:
- White background with a very subtle vertical gradient for depth.
- WORDMARK variant: full "See3D" wordmark centred, ~62% canvas width,
  soft navy-tinted drop shadow.
- MONOGRAM variant: "3D" characters cropped directly from the brand
  wordmark (preserves font and exact navy colour), centred, ~58% canvas
  width. Used at small icon sizes (16/32/64 px) where the full wordmark
  becomes an illegible blur. Apple's own pro apps (Ps, Ai, Pr) follow
  the same wordmark-large / monogram-small pattern.
- No pre-rounded corners - macOS applies its squircle mask at render time,
  Windows renders square.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

HERE   = Path(__file__).resolve().parent.parent
ASSETS = HERE / "assets"

SIZE            = 1024
WORDMARK_WIDTH  = int(SIZE * 0.62)
MONOGRAM_WIDTH  = int(SIZE * 0.58)
BG_TOP          = (255, 255, 255)
BG_BOTTOM       = (242, 246, 251)
SHADOW_OFFY     = 18
SHADOW_BLUR     = 28
SHADOW_OPACITY  = 0.10
SHADOW_TINT     = (0, 27, 135)   # navy, matches brand

# Character X-ranges in See3D Vector.png (1250x350), measured by alpha
# projection. See scripts/_detect_chars.py for the detection method.
CHARS = {
    "S": (53,  249),
    "e1": (269, 466),
    "e2": (484, 681),
    "3": (699, 904),
    "D": (939, 1191),
}
MONOGRAM_CHARS = ("3", "D")
MONOGRAM_GAP   = 24   # px gap between monogram letters at source resolution


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


def make_canvas(logo: Image.Image, target_width: int) -> Image.Image:
    """Place `logo` centred on a 1024x1024 gradient canvas with a soft
    navy-tinted drop shadow underneath."""
    canvas = linear_gradient(SIZE, BG_TOP, BG_BOTTOM)

    aspect = logo.height / logo.width
    w = target_width
    h = int(w * aspect)
    scaled = logo.resize((w, h), Image.LANCZOS)

    x = (SIZE - w) // 2
    y = (SIZE - h) // 2

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste(scaled, (x, y + SHADOW_OFFY), scaled)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    shadow_arr = np.array(shadow)
    shadow_arr[..., 3] = (shadow_arr[..., 3].astype(np.float32) * SHADOW_OPACITY).astype(np.uint8)
    shadow_arr[..., 0] = SHADOW_TINT[0]
    shadow_arr[..., 1] = SHADOW_TINT[1]
    shadow_arr[..., 2] = SHADOW_TINT[2]
    shadow = Image.fromarray(shadow_arr, mode="RGBA")

    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(scaled, (x, y))
    return canvas


def build_monogram_image(src: Image.Image) -> Image.Image:
    """Crop the '3' and 'D' characters from the wordmark and pack them
    side-by-side with the standard inter-letter gap, on a transparent
    canvas just large enough to hold them."""
    pieces = []
    for ch in MONOGRAM_CHARS:
        x0, x1 = CHARS[ch]
        pieces.append(src.crop((x0, 0, x1, src.height)))

    total_w = sum(p.width for p in pieces) + MONOGRAM_GAP * (len(pieces) - 1)
    canvas = Image.new("RGBA", (total_w, src.height), (0, 0, 0, 0))
    cursor = 0
    for p in pieces:
        canvas.alpha_composite(p, (cursor, 0))
        cursor += p.width + MONOGRAM_GAP
    return canvas


def main() -> None:
    src_path = ASSETS / "See3D Vector.png"
    if not src_path.exists():
        raise SystemExit(f"Missing {src_path}")

    src = Image.open(src_path).convert("RGBA")

    # ---- Wordmark variant ----
    wordmark = make_canvas(src, WORDMARK_WIDTH)
    out_word = ASSETS / "app_icon_source.png"
    wordmark.save(out_word, "PNG", optimize=True)
    print(f"Wrote {out_word.name}  ({SIZE}x{SIZE})")

    # ---- Monogram variant ----
    mono_src = build_monogram_image(src)
    monogram = make_canvas(mono_src, MONOGRAM_WIDTH)
    out_mono = ASSETS / "app_icon_mono_source.png"
    monogram.save(out_mono, "PNG", optimize=True)
    print(f"Wrote {out_mono.name}  ({SIZE}x{SIZE})")

    # ---- 512px README/window icon ----
    fav = wordmark.resize((512, 512), Image.LANCZOS)
    fav.save(ASSETS / "favicon-light-512.png", "PNG", optimize=True)
    print(f"Wrote favicon-light-512.png  (512x512)")


if __name__ == "__main__":
    main()
