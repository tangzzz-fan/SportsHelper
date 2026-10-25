"""iPhone Duo 商品图（2007×2853 内屏 / 1398×2034 外屏）。

**注意：这不是从 Duo 模拟器抓的。** 本机只装了 iOS 27.0 运行时，
而 `iPhone Duo` 设备类型要求更新的运行时——`simctl create` 直接返回
`Incompatible device`，试 iOS 27.1 / 27.2 都是 `Invalid runtime`。
所以这里用 iPhone 18 Pro 的真截图排版成 Duo 尺寸。

版式改成两屏并排：Duo 画布宽高比 0.70，是手机的 1.5 倍宽，
单放一张手机卡片会在两边各留 480px 空白，看着像尺寸填错了。
两屏并排才撑得满，也是平板/折叠屏商品图的通行做法。

Apple 规范（2026）：
    iPhone Duo 外屏 1398×2034 / 内屏 2007×2853
    用 iOS 27.1 SDK 及以上的 app，2027 年 4 月起必须提供
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from compose import (ASSETS, BASE_W, FONT_PATH, IDX_BOLD, IDX_REG, INK,
                     INK_SUB, background, draw_tracked)

PHONE_ASPECT = 1320 / 2868

TARGETS = [
    (2007, 2853, "2007x2853-duo-inner"),
    (1398, 2034, "1398x2034-duo-outer"),
]

# (输出名, 标题, 副标题, 左图, 右图)
PAGES = [
    ("01-计划到动作", "从计划到动作，一屏走完", "今天练什么，每组怎么练",
     "1-今日.png", "2-训练中.png"),
    ("02-动作与结果", "50 个动作，都有要领", "配图示、常见错误与降阶替代",
     "4-动作库.png", "5-总结.png"),
]


def card(src: Path, width: int, radius: int) -> Image.Image:
    shot = Image.open(src).convert("RGB")
    h = round(shot.height * width / shot.width)
    shot = shot.resize((width, h), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, width - 1, h - 1], radius=radius, fill=255
    )
    out = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    out.paste(shot, (0, 0))
    out.putalpha(mask)
    return out


def compose_duo(left: Path, right: Path, out: Path, title, subtitle, w, h) -> Path:
    s = w / 1320

    gap = round(w * 0.030)
    card_w = round((w * 0.90 - gap) / 2)
    card_top = round(h * 0.245)
    radius = round(52 * s)

    canvas = background(w, h, s).convert("RGBA")
    cards = [card(left, card_w, radius), card(right, card_w, radius)]
    total = card_w * 2 + gap
    x0 = w // 2 - total // 2

    pad = round(120 * s)
    for i, c in enumerate(cards):
        c = c.crop((0, 0, card_w, min(c.height, h - card_top)))
        x = x0 + i * (card_w + gap)
        shadow = Image.new("RGBA", (card_w + pad * 2, c.height + pad * 2), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            [pad, pad, pad + card_w, pad + c.height], radius=radius, fill=(12, 34, 28, 56)
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(round(34 * s)))
        canvas.alpha_composite(shadow, (x - pad, card_top - pad + round(14 * s)))
        canvas.alpha_composite(c, (x, card_top))

    draw = ImageDraw.Draw(canvas)
    head_size = round(104 * s * 0.92)
    sub_size = round(44 * s)
    head_font = ImageFont.truetype(FONT_PATH, head_size, index=IDX_BOLD)
    sub_font = ImageFont.truetype(FONT_PATH, sub_size, index=IDX_REG)

    y = round(110 * s)
    draw_tracked(draw, title, head_font, w // 2, y, INK, tracking=round(3 * s))
    draw_tracked(draw, subtitle, sub_font, w // 2, y + round(head_size * 1.35), INK_SUB,
                 tracking=round(1 * s))

    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, "PNG", optimize=True)
    return out


def main() -> None:
    for w, h, tag in TARGETS:
        out_dir = ASSETS / "marketing" / tag
        for name, title, sub, a, b in PAGES:
            p = compose_duo(ASSETS / a, ASSETS / b, out_dir / f"{name}.png", title, sub, w, h)
            im = Image.open(p)
            print(f"{tag:<20} {p.name:<16} {im.size} {im.mode} {p.stat().st_size / 1048576:.2f} MB")


if __name__ == "__main__":
    main()
