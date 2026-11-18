"""把三层合成为「眼见的启动屏」，用来在改 storyboard 之前校对视觉。

只做几何换算，不模拟 iOS 的插值方式——三层都是色块和模糊，差异肉眼不可见。
"""

import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = "/Users/tango/Developments/SportsHelper"
ASSETS = f"{ROOT}/DongKe/Assets.xcassets"

BASE = {"light": (10, 95, 82), "dark": (7, 22, 18)}
# (宽, 高, 名字) —— 覆盖小屏与大屏两端
SCREENS = [(393, 852, "iPhone 17 Pro"), (320, 568, "iPhone SE")]
SCALE = 3


def compose(scheme: str, w: int, h: int) -> Image.Image:
    W, H = w * SCALE, h * SCALE
    canvas = Image.new("RGBA", (W, H), BASE[scheme] + (255,))

    glow = Image.open(f"{ASSETS}/LaunchGlow.imageset/LaunchGlow-{scheme}.png").convert("RGBA")
    canvas.alpha_composite(glow.resize((W, H), Image.BICUBIC))

    mark = Image.open(f"{ASSETS}/LaunchMark.imageset/LaunchMark-{scheme}@3x.png").convert("RGBA")
    size = 104 * SCALE
    mark = mark.resize((size, size), Image.LANCZOS)
    # 标记与光心同高（0.42 屏高），不是几何居中
    cx, cy = W // 2, int(H * 0.42)
    canvas.alpha_composite(mark, (cx - size // 2, cy - size // 2))
    return canvas


def strip(images: list[tuple[Image.Image, str]]) -> Image.Image:
    pad, label_h = 40, 60
    total_w = sum(im.width for im, _ in images) + pad * (len(images) + 1)
    total_h = max(im.height for im, _ in images) + pad * 2 + label_h
    out = Image.new("RGB", (total_w, total_h), (236, 234, 232))
    x = pad
    draw = ImageDraw.Draw(out)
    for im, label in images:
        out.paste(im.convert("RGB"), (x, pad))
        draw.text((x + 4, pad + im.height + 12), label, fill=(40, 40, 40))
        x += im.width + pad
    return out


if __name__ == "__main__":
    rows = []
    for scheme in ("light", "dark"):
        ims = [(compose(scheme, w, h), f"{name} · {scheme}") for w, h, name in SCREENS]
        rows.append(strip(ims))

    width = max(r.width for r in rows)
    height = sum(r.height for r in rows)
    sheet = Image.new("RGB", (width, height), (236, 234, 232))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    path = f"{ROOT}/.scratch/launchscreen/preview.png"
    sheet.save(path)
    print(f"{path}  {sheet.size}")
