"""Generates Vaulta launcher icons for Android, iOS, macOS, Windows and
web from the brand SVGs in redesign/brand.

The SVGs use simple primitives (rect, path, gradient), so this script
re-implements them in PIL to avoid the cairo native dependency. The
visual result is identical to the SVGs at the resolutions we ship.
"""
from __future__ import annotations

import os
import math
from pathlib import Path

from PIL import Image, ImageDraw

# Resolved from this file's location so the script works in any clone.
# Override with VAULTA_REPO_ROOT if you run it from somewhere else.
REPO = Path(os.environ.get("VAULTA_REPO_ROOT", Path(__file__).resolve().parent.parent))
BRAND_DIR = REPO / "redesign" / "brand"

# --- Brand colors (kept in sync with cv-app-icon-ink.svg) -----------
INK_TOP = (0x15, 0x15, 0x1A, 255)
INK_BOT = (0x0A, 0x0A, 0x0B, 255)
CRIMSON = (0x9B, 0x1B, 0x1F, 255)
PAPER = (0xF5, 0xF2, 0xEA, 255)
GOLD = (0xF2, 0xC7, 0x0F, 255)


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def vertical_gradient(size: int, top_rgba, bot_rgba) -> Image.Image:
    """Linear top->bottom gradient."""
    img = Image.new("RGBA", (size, size), top_rgba)
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = (
            lerp(top_rgba[0], bot_rgba[0], t),
            lerp(top_rgba[1], bot_rgba[1], t),
            lerp(top_rgba[2], bot_rgba[2], t),
            255,
        )
    # Fill the rest of each row
    for y in range(size):
        for x in range(1, size):
            px[x, y] = px[0, y]
    return img


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def draw_logo(img: Image.Image) -> None:
    """Draws the padlock + V-shackle + gold detail at native size.
    The shape mirrors cv-app-icon-ink.svg translated/scaled to fit a
    1024x1024 viewBox and is then redrawn at the target resolution.
    """
    size = img.size[0]
    draw = ImageDraw.Draw(img)
    # The symbol lives in a 480x480 box centered in the 1024 canvas.
    # Scale that ratio to the current size.
    box = int(size * 480 / 1024)
    offset = (size - box) // 2

    # Padlock body (chamfered pentagon): SVG path
    # M 36 52 L 30 58 L 30 100 L 90 100 L 90 58 L 84 52 Z
    # Normalized to the 120-unit viewBox: 36/120..90/120.
    def to_px(v: float) -> float:
        return offset + v * box / 120.0

    body = [
        (to_px(36), to_px(52)),
        (to_px(30), to_px(58)),
        (to_px(30), to_px(100)),
        (to_px(90), to_px(100)),
        (to_px(90), to_px(58)),
        (to_px(84), to_px(52)),
    ]
    draw.polygon(body, fill=CRIMSON)

    # Shackle: M 42 52 L 42 30 L 60 48 L 78 30 L 78 52
    # A single 5-point polyline — matches the SVG path 1:1 and
    # uses miter joins at the apex.
    shackle_w = max(int(box * 7 / 120), 2)
    shackle = [
        (to_px(42), to_px(52)),
        (to_px(42), to_px(30)),
        (to_px(60), to_px(48)),
        (to_px(78), to_px(30)),
        (to_px(78), to_px(52)),
    ]
    draw.line(shackle, fill=PAPER, width=shackle_w, joint="miter")

    # Gold bar
    bar = [to_px(40), to_px(70), to_px(80), to_px(70) + max(int(box * 2.5 / 120), 1)]
    draw.rectangle(
        (to_px(40), to_px(70), to_px(80), to_px(70) + max(int(box * 2.5 / 120), 1)),
        fill=GOLD,
    )

    # Gold keyhole
    kx0 = to_px(56)
    ky0 = to_px(78)
    kx1 = to_px(64)
    ky1 = to_px(86)
    draw.rectangle((kx0, ky0, kx1, ky1), fill=GOLD)


def render(size: int, radius_ratio: float = 230 / 1024) -> Image.Image:
    radius = max(int(size * radius_ratio), 1)
    bg = vertical_gradient(size, INK_TOP, INK_BOT)
    mask = rounded_rect_mask(size, radius)
    bg.putalpha(mask)
    draw_logo(bg)
    return bg


def write(path: Path, size: int) -> None:
    img = render(size)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"wrote {path} ({size}x{size})")


def main() -> None:
    # Android launcher icons (mipmap-*)
    android_targets = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_targets.items():
        write(
            REPO / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
            size,
        )

    # iOS appiconset — keep existing sizes, just overwrite with the brand
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    ios_dir = REPO / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for filename, size in ios_sizes.items():
        write(ios_dir / filename, size)

    # macOS appiconset — same canvas sizes as iOS
    macos_dir = REPO / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if macos_dir.exists():
        for filename, size in ios_sizes.items():
            write(macos_dir / filename, size)

    # Web manifest icons + favicon
    web_targets = {
        "icons/Icon-192.png": 192,
        "icons/Icon-512.png": 512,
        "icons/Icon-maskable-192.png": 192,
        "icons/Icon-maskable-512.png": 512,
    }
    for rel, size in web_targets.items():
        write(REPO / "web" / rel, size)
    write(REPO / "web" / "favicon.png", 32)

    # Windows .ico — PIL needs sizes list
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    ico_dir = REPO / "windows" / "runner" / "resources"
    ico_dir.mkdir(parents=True, exist_ok=True)
    base = render(256)
    base.save(
        ico_dir / "app_icon.ico",
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
    )
    print(f"wrote {ico_dir / 'app_icon.ico'} (multi-res)")


if __name__ == "__main__":
    main()
