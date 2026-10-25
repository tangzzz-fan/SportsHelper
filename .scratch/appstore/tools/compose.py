"""把原始截图排版成 App Store 商品图。

**尺寸不是 1320×2868。** Apple 2026 年的规范改了分档：必需的是
「iPhone with Dynamic Island (**medium** display)」，也就是 iPhone 18 Pro /
17 Pro / 16 Pro 这一档，接受 1179×2556 与 **1206×2622**。
1320×2868 属于「Dynamic Island (large display)」，那是可选档。

    iPhone with Dynamic Island (large)   iPhone Air / 18 Pro Max / 17 Pro Max …
                                        1260×2736 · 1290×2796 · 1320×2868
    iPhone with Dynamic Island (medium)  iPhone 18 Pro / 17 Pro / 16 Pro / 15 Pro
                                        1179×2556 · **1206×2622**   ← 必需
    iPhone with Face ID (large)          1284×2778 · 1242×2688（没提供上面那档时才用）

所以默认出 1206×2622，另外顺带出一套 1320×2868 备用。所有排版常量按画布宽
等比缩放，两套是同一份设计，不是把大图缩下来的。

三条硬要求：精确像素、RGB 不带 alpha、单张 ≤ 8 MB。
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# 设计稿基准宽度：所有常量按这个宽度写，渲染时按目标宽等比缩放。
BASE_W = 1320

FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
IDX_BOLD = 2   # Hiragino Sans GB W6
IDX_REG = 0    # Hiragino Sans GB W3

INK = (16, 36, 31)
INK_SUB = (84, 102, 96)

ASSETS = Path("/Users/tango/Developments/SportsHelper/.scratch/appstore/assets")

# 目标尺寸：必需档 + 可选的大屏档
TARGETS = [
    (1206, 2622, "1206x2622"),   # Dynamic Island (medium) —— 必需
    (1320, 2868, "1320x2868"),   # Dynamic Island (large) —— 可选
]

# (源文件, 输出名, 标题两行, 副标题)
#
# 只放 5 张：`3-计划.png` 底部那排浮动标签栏压在 AI 输入框上、下面的
# 「动作库 / 导入计划 / 调整」被裁掉一半，是真实布局缺陷，当商品图不行。
PAGES = [
    ("1-今日.png", "01-今日", ("今天练什么", "已经排好了"), "按目标、器材、时间自动排课"),
    ("2-训练中.png", "02-训练中", ("跟着做就行", "不用记组数"), "首组讲要领，之后只报数"),
    ("4-动作库.png", "03-动作库", ("每个动作", "都有要领"), "50 个动作，配图示与降阶"),
    ("5-总结.png", "04-总结", ("完成了多少", "一眼看清"), "完成率、降阶、跳过分开记"),
    ("6-记录.png", "05-记录", ("练过的", "都算数"), "每周有效组、训练天、连续天数"),
]


def background(w: int, h: int, s: float) -> Image.Image:
    y = np.linspace(0, 1, h)[:, None, None]
    top = np.array([226, 240, 234], dtype=np.float32)
    bottom = np.array([243, 244, 246], dtype=np.float32)
    img = np.repeat(top * (1 - y) + bottom * y, w, axis=1)

    xs = np.arange(w)[None, :]
    ys = np.arange(h)[:, None]
    dist = np.sqrt((xs - w / 2) ** 2 + (ys - 240 * s) ** 2)
    glow = np.clip(1 - dist / (900 * s), 0, 1) ** 2 * 0.14
    img = img * (1 - glow[..., None]) + np.array([14, 124, 102]) * glow[..., None]
    return Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")


def draw_tracked(draw, text, font, center_x, top, fill, tracking):
    """PIL 没有字距，逐字画。中文标题加一点字距会松快很多。"""
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = center_x - total / 2
    for ch, cw in zip(text, widths):
        draw.text((x, top), ch, font=font, fill=fill)
        x += cw + tracking


def compose(src: Path, out: Path, headline, subline, w: int, h: int) -> Path:
    s = w / BASE_W
    card_w = round(1120 * s)
    card_top = round(520 * s)
    radius = round(52 * s)
    head_size = round(104 * s)
    sub_size = round(44 * s)
    head_top = round(136 * s)
    head_step = round(head_size * 1.2)
    sub_gap = round(34 * s)

    shot = Image.open(src).convert("RGB")
    card_h = round(shot.height * card_w / shot.width)
    shot = shot.resize((card_w, card_h), Image.LANCZOS)

    # 先圆角再裁底：反过来的话圆角落在裁切边上，画布最底下会抠出两个豁口。
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, shot.width - 1, shot.height - 1], radius=radius, fill=255
    )
    card = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    card.paste(shot, (0, 0))
    card.putalpha(mask)
    card = card.crop((0, 0, card_w, min(card_h, h - card_top)))

    canvas = background(w, h, s).convert("RGBA")
    card_x = w // 2 - card_w // 2

    pad = round(120 * s)
    shadow = Image.new("RGBA", (card_w + pad * 2, card.height + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad, pad + card_w, pad + card.height], radius=radius, fill=(12, 34, 28, 64)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(34 * s)))
    canvas.alpha_composite(shadow, (card_x - pad, card_top - pad + round(14 * s)))
    canvas.alpha_composite(card, (card_x, card_top))

    draw = ImageDraw.Draw(canvas)
    head_font = ImageFont.truetype(FONT_PATH, head_size, index=IDX_BOLD)
    sub_font = ImageFont.truetype(FONT_PATH, sub_size, index=IDX_REG)

    y = head_top
    for line in headline:
        draw_tracked(draw, line, head_font, w // 2, y, INK, tracking=round(3 * s))
        y += head_step
    draw_tracked(draw, subline, sub_font, w // 2, y + sub_gap, INK_SUB, tracking=round(1 * s))

    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, "PNG", optimize=True)
    return out


def main() -> None:
    for w, h, tag in TARGETS:
        out_dir = ASSETS / "marketing" / tag
        for src_name, out_name, head, sub in PAGES:
            src = ASSETS / src_name
            if not src.exists():
                print("缺", src)
                continue
            p = compose(src, out_dir / f"{out_name}.png", head, sub, w, h)
            im = Image.open(p)
            print(f"{tag:<10} {p.name:<14} {im.size} {im.mode} {p.stat().st_size / 1048576:.2f} MB")
    print("->", ASSETS / "marketing")


if __name__ == "__main__":
    main()
