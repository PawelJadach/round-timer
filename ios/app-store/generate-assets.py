#!/usr/bin/env python3
"""Generate Round Timer App Store icon and marketing screenshots."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT_DIR = ROOT.parent / "MMAClock" / "Fonts"
WEB_FONTS = ROOT.parent.parent / "web" / "fonts"

BG = (16, 12, 10)
INK = (244, 239, 230)
GOLD = (228, 177, 90)
WORK = (226, 58, 43)
PREPARE = GOLD
MUTED = (180, 170, 155)


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    for folder in (FONT_DIR, WEB_FONTS):
        path = folder / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    raise FileNotFoundError(name)


def draw_ring_corners(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    length = 26
    inset = 14
    for cx, cy, sx, sy in (
        (x0 + inset, y0 + inset, 1, 1),
        (x1 - inset, y0 + inset, -1, 1),
        (x0 + inset, y1 - inset, 1, -1),
        (x1 - inset, y1 - inset, -1, -1),
    ):
        draw.line([(cx, cy), (cx + sx * length, cy)], fill=GOLD, width=3)
        draw.line([(cx, cy), (cx, cy + sy * length)], fill=GOLD, width=3)


def radial_glow(base: Image.Image, color: tuple[int, int, int], cy: int) -> Image.Image:
    w, _ = base.size
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for radius in range(280, 0, -4):
        alpha = int(95 * (radius / 280) ** 2)
        draw.ellipse((w // 2 - radius, cy - radius, w // 2 + radius, cy + radius), fill=(*color, alpha))
    return Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")


def make_icon(out: Path) -> None:
    size = 1024
    img = Image.new("RGB", (size, size), BG)
    img = radial_glow(img, WORK, 280)
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    draw.ellipse((cx - 330, cy - 330, cx + 330, cy + 330), outline=GOLD, width=8)
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        draw.line(
            (
                (cx + int(math.cos(rad) * 330), cy + int(math.sin(rad) * 330)),
                (cx + int(math.cos(rad) * 410), cy + int(math.sin(rad) * 410)),
            ),
            fill=GOLD,
            width=6,
        )
    time_font = load_font("BarlowCondensed-Bold.ttf", 250)
    label_font = load_font("BarlowCondensed-Bold.ttf", 120)
    draw.text((cx, cy - 80), "03:00", font=time_font, fill=INK, anchor="mm")
    draw.text((cx, cy + 150), "ROUND", font=label_font, fill=WORK, anchor="mm")
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


def draw_mode_bar(draw: ImageDraw.ImageDraw, y: int, labels: list[str], active: int, lang: str) -> None:
    pill_font = load_font("BarlowCondensed-SemiBold.ttf", 34)
    x = 80
    for index, label in enumerate(labels):
        pad_x, pad_y = 28, 16
        bbox = draw.textbbox((0, 0), label, font=pill_font)
        width = bbox[2] - bbox[0] + pad_x * 2
        height = bbox[3] - bbox[1] + pad_y * 2
        fill = (int(GOLD[0] * 0.22), int(GOLD[1] * 0.22), int(GOLD[2] * 0.15)) if index == active else (40, 28, 22)
        draw.rounded_rectangle((x, y, x + width, y + height), radius=30, fill=fill, outline=GOLD, width=2)
        draw.text((x + pad_x, y + pad_y - 4), label, font=pill_font, fill=GOLD if index == active else MUTED)
        x += width + 12
    lang_x = 700
    for code in ("EN", "PL"):
        selected = code.lower() == lang
        draw.rounded_rectangle((lang_x, y, lang_x + 86, y + 64), radius=30,
                               fill=GOLD if selected else (40, 28, 22), outline=GOLD, width=2)
        draw.text((lang_x + 43, y + 32), code, font=pill_font, fill=BG if selected else MUTED, anchor="mm")
        lang_x += 96


def screenshot(lang: str, phase: str, time_text: str, detail: str, tint: tuple[int, int, int], out: Path) -> None:
    width, height = 1290, 2796
    img = Image.new("RGB", (width, height), BG)
    img = radial_glow(img, tint, 520)
    draw = ImageDraw.Draw(img)

    if lang == "en":
        modes = ["SPARRING", "TIMER", "STOPWATCH"]
        volume = "VOLUME"
    else:
        modes = ["SPARING", "MINUTNIK", "STOPER"]
        volume = "GŁOŚNOŚĆ"

    draw_mode_bar(draw, 120, modes, 0, lang)
    draw.text((80, 220), volume, font=load_font("BarlowCondensed-SemiBold.ttf", 30), fill=MUTED)
    draw.rounded_rectangle((220, 230, 1040, 260), radius=8, fill=(40, 28, 22), outline=GOLD, width=2)
    draw.rectangle((220, 230, 900, 260), fill=GOLD)

    draw_ring_corners(draw, (90, 560, width - 90, 1120))
    draw.text((width // 2, 660), phase, font=load_font("BarlowCondensed-Bold.ttf", 52), fill=tint, anchor="mm")
    draw.text((width // 2, 850), time_text, font=load_font("BarlowCondensed-Bold.ttf", 220), fill=INK, anchor="mm")
    draw.text((width // 2, 1010), detail, font=load_font("Barlow-Medium.ttf", 42), fill=MUTED, anchor="mm")

    draw.rounded_rectangle((120, 1280, width - 120, 1400), radius=60, fill=WORK)
    draw.text((width // 2, 1340), "START", font=load_font("BarlowCondensed-Bold.ttf", 56), fill=BG, anchor="mm")

    credit = "Bell: Benboncan, CC BY 4.0." if lang == "en" else "Dzwonek: Benboncan, CC BY 4.0."
    draw.text((width // 2, 2520), credit, font=load_font("Barlow-Medium.ttf", 28), fill=MUTED, anchor="mm")

    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


def main() -> None:
    icon_path = ROOT / "icon" / "AppIcon-1024.png"
    make_icon(icon_path)
    make_icon(ROOT.parent / "MMAClock" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png")

    shots = ROOT / "screenshots"
    screenshot("en", "PREPARE", "00:10", "Starting soon", PREPARE, shots / "en" / "01-sparring-setup.png")
    screenshot("en", "WORK", "02:47", "Round 1 of 5", WORK, shots / "en" / "02-work-round.png")
    screenshot("pl", "PRZYGOTOWANIE", "00:10", "Zaraz start", PREPARE, shots / "pl" / "01-sparring-setup.png")
    screenshot("pl", "PRACA", "02:47", "Runda 1 z 5", WORK, shots / "pl" / "02-work-round.png")
    print(f"Generated assets under {ROOT}")


if __name__ == "__main__":
    main()
