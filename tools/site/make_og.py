# -*- coding: utf-8 -*-
"""Build the 1200x630 Open Graph card for the StarGate website."""
from __future__ import annotations

import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, "docs", "assets")
OUT = os.path.join(ASSETS, "og.png")
W, H = 1200, 630

FONT_CN = "C:/Windows/Fonts/msyhbd.ttc"
FONT_CN_REG = "C:/Windows/Fonts/msyh.ttc"
FONT_LATIN = "C:/Windows/Fonts/seguisb.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def gradient_background() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = yy / (H - 1)

    top = np.array([7, 15, 29], dtype=np.float32)
    bottom = np.array([5, 9, 17], dtype=np.float32)
    base = top[None, None, :] * (1 - t[..., None]) + bottom[None, None, :] * t[..., None]

    # soft blue portal glow behind the card
    cx, cy, radius = 900.0, 290.0, 620.0
    dist = np.sqrt(((xx - cx) / radius) ** 2 + ((yy - cy) / radius) ** 2)
    glow = np.clip(1 - dist, 0, 1) ** 2.2
    base += glow[..., None] * np.array([18, 48, 92], dtype=np.float32)

    # subtle teal wash at lower left
    dist2 = np.sqrt(((xx - 170) / 620.0) ** 2 + ((yy - 600) / 360.0) ** 2)
    glow2 = np.clip(1 - dist2, 0, 1) ** 3
    base += glow2[..., None] * np.array([4, 34, 38], dtype=np.float32)

    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def add_stars(base: Image.Image) -> None:
    rng = random.Random(20261110)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(260):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        # keep most stars subtle; a handful catch the light
        r = rng.choices([1, 1, 1, 1.4, 1.8], weights=[40, 30, 18, 9, 3])[0]
        alpha = int(rng.uniform(45, 170))
        tint = rng.choice([(255, 255, 255), (190, 226, 255), (190, 245, 255)])
        draw.ellipse((x - r, y - r, x + r, y + r), fill=tint + (alpha,))
    # a few brighter stars with a small halo
    for _ in range(12):
        x = rng.uniform(40, W - 40)
        y = rng.uniform(40, H - 40)
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(160, 225, 255, 18))
        draw.ellipse((x - 1.3, y - 1.3, x + 1.3, y + 1.3), fill=(255, 255, 255, 190))
    base.alpha_composite(layer)


def add_rings(base: Image.Image) -> None:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = 905, 305
    for radius, alpha, width in [(245, 52, 1), (310, 34, 1), (382, 24, 1), (455, 14, 1)]:
        box = (cx - radius, cy - radius, cx + radius, cy + radius)
        draw.ellipse(box, outline=(87, 202, 244, alpha), width=width)
    # faint arc highlight on the left side
    for radius, alpha in [(310, 80), (382, 55)]:
        box = (cx - radius, cy - radius, cx + radius, cy + radius)
        draw.arc(box, start=118, end=226, fill=(145, 237, 255, alpha), width=2)
    base.alpha_composite(layer)


def rounded_image(path: str, width: int, radius: int) -> Image.Image:
    img = Image.open(path).convert("RGB")
    height = round(img.height * width / img.width)
    img = img.resize((width, height), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    img.putalpha(mask)
    return img


def add_card(base: Image.Image) -> None:
    card_w = 424
    card = rounded_image(os.path.join(ASSETS, "card.webp"), card_w, 26)
    card_h = card.height
    x = 724
    y = 94

    # blue halo
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle((x - 50, y - 40, x + card_w + 50, y + card_h + 55), radius=60,
                         fill=(48, 122, 255, 80))
    glow = glow.filter(ImageFilter.GaussianBlur(58))
    base.alpha_composite(glow)

    # drop shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 8, y + 18, x + card_w + 14, y + card_h + 28), radius=30,
                         fill=(0, 0, 0, 185))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    base.alpha_composite(shadow)

    # thin metallic frame
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle((x - 7, y - 7, x + card_w + 6, y + card_h + 6), radius=32,
                         fill=(255, 255, 255, 22), outline=(190, 230, 255, 85), width=1)
    base.alpha_composite(frame)
    base.alpha_composite(card, (x, y))


def add_text(base: Image.Image) -> None:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    logo = Image.open(os.path.join(ASSETS, "logo.webp")).convert("RGBA").resize((58, 58), Image.LANCZOS)
    base.alpha_composite(logo, (80, 62))

    f_brand = font(FONT_CN, 23)
    draw.text((153, 74), "星门 StarGate", font=f_brand, fill=(238, 246, 255, 255))

    # kicker
    f_kick = font(FONT_LATIN, 13)
    draw.text((154, 108), "HARMONYOS NEXT  ·  OPEN SOURCE", font=f_kick, fill=(120, 200, 225, 185))

    f_title = font(FONT_CN, 66)
    f_title_latin = font(FONT_LATIN, 64)
    title_y = 186
    # line 1: mixed Latin and Chinese; draw as one run for rhythm
    draw.text((80, title_y + 3), "跨过 App 的门", font=f_title, fill=(0, 0, 0, 120))
    draw.text((80, title_y), "跨过 App 的门", font=f_title, fill=(248, 251, 255, 255))
    draw.text((80, title_y + 84), "一步抵达功能", font=f_title, fill=(0, 0, 0, 120))
    draw.text((80, title_y + 81), "一步抵达功能", font=f_title, fill=(100, 230, 255, 255))

    f_sub = font(FONT_CN_REG, 25)
    draw.text((82, 377), "面向 HarmonyOS 的应用原子能力聚合与直达平台",
              font=f_sub, fill=(192, 207, 225, 255))

    f_meta = font(FONT_CN_REG, 16)
    draw.text((83, 426), "桌面卡片   ·   搜索   ·   分类   ·   一键直达",
              font=f_meta, fill=(113, 159, 184, 255))

    # thin divider + footer
    draw.line((82, 526, 520, 526), fill=(120, 175, 205, 42), width=1)
    f_foot = font(FONT_CN_REG, 14)
    draw.text((83, 550), "软件学院 SMAT 项目组", font=f_foot, fill=(93, 119, 145, 255))
    draw.text((83, 576), "growvv.github.io/stargate", font=font(FONT_LATIN, 12),
              fill=(79, 126, 153, 255))

    # small live-dot beside the kicker
    draw.ellipse((80 + 0, 114, 80 + 7, 121), fill=(103, 232, 249, 230))
    draw.ellipse((80 - 3, 111, 80 + 10, 124), outline=(103, 232, 249, 36), width=1)

    base.alpha_composite(layer)


def main() -> None:
    base = gradient_background()
    add_stars(base)
    add_rings(base)
    add_card(base)
    add_text(base)

    # gentle vignette so the card and type sit in the frame
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = (xx - W / 2) / (W / 2)
    dy = (yy - H / 2) / (H / 2)
    vignette = np.clip((dx * dx + dy * dy - 0.35) * 0.16, 0, 0.22)
    arr = np.asarray(base.convert("RGB"), dtype=np.float32)
    arr *= (1 - vignette[..., None])
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    out.save(OUT, optimize=True)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
