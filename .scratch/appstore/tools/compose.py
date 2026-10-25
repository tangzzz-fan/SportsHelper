"""把已抓好的原始截图排版成 App Store 商品图（6.9" / 1320×2868）。

不重新截图，只做排版。上架对商品图有两条硬要求，逐条落掉：

1. **尺寸必须精确 1320×2868**（6.9 英寸竖屏，差一像素传不上去）
2. **不能带 alpha 通道**——RGBA 是上传失败最常见的原因，这里统一落成 RGB

排版用「标题 + 整屏卡片」：标题在浅绿渐变上，下方是完整一屏。
卡片底部溢出画布，只切掉 home indicator 那条空白，不动任何控件。

正文数字都是真的：50 个动作 = `ExerciseLibrary.all.count`，
92% 是总结页实际渲染出来的值。
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CANVAS = (1320, 2868)
CARD_W = 1120
CARD_TOP = 520
RADIUS = 52

HEAD = 104
SUB = 44
HEAD_TOP = 136
SUB_GAP = 34

FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
IDX_BOLD = 2   # Hiragino Sans GB W6
IDX_REG = 0    # Hiragino Sans GB W3

INK = (16, 36, 31)
INK_SUB = (84, 102, 96)

ASSETS = Path("/Users/tango/Developments/SportsHelper/.scratch/appstore/assets")
OUT = ASSETS / "marketing"

# (源文件, 输出名, 标题两行, 副标题)
#
# 只放 5 张：`3-计划.png` 底部那排浮动标签栏压在 AI 输入框上、下方的
# 「动作库 / 导入计划 / 调整」被裁掉一半，是真实的布局缺陷，当商品图不行。
# 等那个布局修好重拍，再补成 6 张。
PAGES = [
    ("1-今日.png", "01-今日", ("今天练什么", "已经排好了"), "按目标、器材、时间自动排课"),
    ("2-训练中.png", "02-训练中", ("跟着做就行", "不用记组数"), "首组讲要领，之后只报数"),
    ("4-动作库.png", "03-动作库", ("每个动作", "都有要领"), "50 个动作，配图示与降阶"),
    ("5-总结.png", "04-总结", ("完成了多少", "一眼看清"), "完成率、降阶、跳过分开记"),
    ("6-记录.png", "05-记录", ("练过的", "都算数"), "每周有效组、训练天、连续天数"),
]


def background() -> Image.Image:
    w, h = CANVAS
    y = np.linspace(0, 1, h)[:, None, None]
    top = np.array([226, 240, 234], dtype=np.float32)
    bottom = np.array([243, 244, 246], dtype=np.float32)
    img = np.repeat(top * (1 - y) + bottom * y, w, axis=1)

    xs = np.arange(w)[None, :]
    ys = np.arange(h)[:, None]
    dist = np.sqrt((xs - w / 2) ** 2 + (ys - 240) ** 2)
    glow = np.clip(1 - dist / 900.0, 0, 1) ** 2 * 0.14
    img = img * (1 - glow[..., None]) + np.array([14, 124, 102]) * glow[..., None]
    return Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")


def draw_tracked(draw, text, font, center_x, top, fill, tracking=2):
    """PIL 没有字距，逐字画。中文标题加一点字距会松快很多。"""
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = center_x - total / 2
    for ch, cw in zip(text, widths):
        draw.text((x, top), ch, font=font, fill=fill)
        x += cw + tracking


def compose(src: Path, out: Path, headline, subline) -> Path:
    shot = Image.open(src).convert("RGB")
    card_h = round(shot.height * CARD_W / shot.width)
    shot = shot.resize((CARD_W, card_h), Image.LANCZOS)

    # 先圆角再裁底。反过来的话圆角会落在被裁后的边缘上，
    # 在画布最底下抠出两个豁口，看着像卡片没铺满。
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, shot.width - 1, shot.height - 1], radius=RADIUS, fill=255
    )
    card = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    card.paste(shot, (0, 0))
    card.putalpha(mask)

    visible = CANVAS[1] - CARD_TOP
    card = card.crop((0, 0, CARD_W, min(card_h, visible)))

    canvas = background().convert("RGBA")
    card_x = CANVAS[0] // 2 - CARD_W // 2

    shadow = Image.new("RGBA", (CARD_W + 240, card.height + 240), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [120, 120, 120 + CARD_W, 120 + card.height], radius=RADIUS, fill=(12, 34, 28, 64)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow, (card_x - 120, CARD_TOP - 120 + 14))
    canvas.alpha_composite(card, (card_x, CARD_TOP))

    draw = ImageDraw.Draw(canvas)
    head_font = ImageFont.truetype(FONT_PATH, HEAD, index=IDX_BOLD)
    sub_font = ImageFont.truetype(FONT_PATH, SUB, index=IDX_REG)

    y = HEAD_TOP
    for line in headline:
        draw_tracked(draw, line, head_font, CANVAS[0] // 2, y, INK, tracking=3)
        y += round(HEAD * 1.2)
    draw_tracked(draw, subline, sub_font, CANVAS[0] // 2, y + SUB_GAP, INK_SUB, tracking=1)

    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, "PNG", optimize=True)
    return out


def main() -> None:
    for src_name, out_name, head, sub in PAGES:
        src = ASSETS / src_name
        if not src.exists():
            print("缺", src)
            continue
        p = compose(src, OUT / f"{out_name}.png", head, sub)
        im = Image.open(p)
        print(f"{p.name:<14} {im.size} {im.mode} {p.stat().st_size / 1048576:.2f} MB")
    print("->", OUT)


if __name__ == "__main__":
    main()
