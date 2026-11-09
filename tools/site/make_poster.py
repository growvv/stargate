# -*- coding: utf-8 -*-
"""Build the 1280x720 poster used by the website's demo video."""
from __future__ import annotations

import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, "docs", "assets")
OUT = os.path.join(ASSETS, "demo-poster.webp")
W, H = 1280, 720

FONT_CN = "C:/Windows/Fonts/msyhbd.ttc"
FONT_CN_REG = "C:/Windows/Fonts/msyh.ttc"
FONT_LATIN = "C:/Windows/Fonts/seguisb.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def background() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = yy / (H - 1)
    top = np.array([7, 14, 27], dtype=np.float32)
    bottom = np.array([5, 9, 17], dtype=np.float32)
    base = top[None, None, :] * (1 - t[..., None]) + bottom[None, None, :] * t[..., None]

    cx, cy, radius = 930.0, 340.0, 690.0
    dist = np.sqrt(((xx - cx) / radius) ** 2 + ((yy - cy) / radius) ** 2)
    glow = np.clip(1 - dist, 0, 1) ** 2.2
    base += glow[..., None] * np.array([20, 50, 94], dtype=np.float32)

    dist2 = np.sqrt(((xx - 120) / 620.0) ** 2 + ((yy - 710) / 420.0) ** 2)
    glow2 = np.clip(1 - dist2, 0, 1) ** 3
    base += glow2[..., None] * np.array([3, 28, 34], dtype=np.float32)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def stars(base: Image.Image) -> None:
    rng = random.Random(20261111)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(300):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.choices([1, 1, 1, 1.4, 1.8], weights=[40, 30, 18, 9, 3])[0]
        alpha = int(rng.uniform(40, 160))
        tint = rng.choice([(255, 255, 255), (190, 226, 255), (190, 245, 255)])
        draw.ellipse((x - r, y - r, x + r, y + r), fill=tint + (alpha,))
    for _ in range(14):
        x, y = rng.uniform(30, W - 30), rng.uniform(30, H - 30)
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(160, 225, 255, 18))
        draw.ellipse((x - 1.3, y - 1.3, x + 1.3, y + 1.3), fill=(255, 255, 255, 190))
    base.alpha_composite(layer)


def rings(base: Image.Image) -> None:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = 940, 360
    for radius, alpha in [(270, 46), (340, 30), (425, 22), (510, 12)]:
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                     outline=(87, 202, 244, alpha), width=1)
    for radius, alpha in [(340, 75), (425, 48)]:
        draw.arc((cx - radius, cy - radius, cx + radius, cy + radius),
                 start=120, end=230, fill=(145, 237, 255, alpha), width=2)
    base.alpha_composite(layer)


def rounded(path: str, width: int, radius: int) -> Image.Image:
    img = Image.open(path).convert("RGB")
    height = round(img.height * width / img.width)
    img = img.resize((width, height), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    img.putalpha(mask)
    return img


def card(base: Image.Image) -> tuple[int, int, int, int]:
    cw = 420
    im = rounded(os.path.join(ASSETS, "card.webp"), cw, 26)
    x, y = 770, 148
    ch = im.height

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle((x - 55, y - 45, x + cw + 55, y + ch + 60),
                                           radius=60, fill=(48, 122, 255, 80))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x + 8, y + 18, x + cw + 14, y + ch + 28),
                                             radius=30, fill=(0, 0, 0, 180))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)))

    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((x - 7, y - 7, x + cw + 6, y + ch + 6),
                                            radius=32, fill=(255, 255, 255, 20),
                                            outline=(190, 230, 255, 80), width=1)
    base.alpha_composite(frame)
    base.alpha_composite(im, (x, y))
    return x, y, cw, ch


def text(base: Image.Image) -> None:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    logo = Image.open(os.path.join(ASSETS, "logo.webp")).convert("RGBA").resize((44, 44), Image.LANCZOS)
    base.alpha_composite(logo, (72, 52))
    draw.text((128, 59), "星门 StarGate", font=font(FONT_CN, 19), fill=(238, 246, 255, 255))
    draw.text((128, 86), "HARMONYOS NEXT  ·  PRODUCT DEMO",
              font=font(FONT_LATIN, 10), fill=(120, 200, 225, 175))

    draw.text((74, 198), "完整演示", font=font(FONT_CN, 76), fill=(248, 251, 255, 255))
    draw.text((74, 292), "从桌面卡片，到目标功能页。",
              font=font(FONT_CN_REG, 27), fill=(192, 207, 225, 255))

    # feature pills
    labels = ["桌面卡片", "搜索", "分类", "设置"]
    x = 76
    for label in labels:
        f = font(FONT_CN_REG, 15)
        box = draw.textbbox((0, 0), label, font=f)
        tw = box[2] - box[0]
        draw.rounded_rectangle((x, 356, x + tw + 26, 392), radius=9,
                               fill=(255, 255, 255, 12), outline=(150, 210, 240, 48), width=1)
        draw.text((x + 13, 365), label, font=f, fill=(180, 219, 234, 235))
        x += tw + 38

    # duration and url
    draw.ellipse((76, 551, 106, 581), outline=(103, 232, 249, 80), width=1)
    draw.polygon([(86, 559), (86, 573), (98, 566)], fill=(160, 240, 255, 220))
    draw.text((120, 555), "4 分 50 秒  ·  真机实录",
              font=font(FONT_CN_REG, 15), fill=(123, 166, 189, 255))
    draw.text((76, 624), "growvv.github.io/stargate", font=font(FONT_LATIN, 13),
              fill=(80, 128, 156, 255))
    draw.text((76, 652), "软件学院 SMAT 项目组", font=font(FONT_CN_REG, 13),
              fill=(88, 116, 143, 255))

    base.alpha_composite(layer)


def main() -> None:
    base = background()
    stars(base)
    rings(base)
    card(base)
    text(base)

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = (xx - W / 2) / (W / 2)
    dy = (yy - H / 2) / (H / 2)
    vignette = np.clip((dx * dx + dy * dy - 0.35) * 0.16, 0, 0.22)
    arr = np.asarray(base.convert("RGB"), dtype=np.float32)
    arr *= (1 - vignette[..., None])
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    out.save(OUT, "WEBP", quality=88, method=6)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
