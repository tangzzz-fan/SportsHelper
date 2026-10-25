"""从 AppIcon 提取标记，去掉绿色底，按「视觉重心」居中生成 LaunchMark 三档。

两个坑：
1. 判据必须用色差（G-R / B-R）而不是亮度 —— 图标背景有径向高光，
   中心亮度接近白，用亮度阈值会连高光一起抠进来，在浅色底上留一块方形残影。
2. 对齐要用「不透明面积质心」而不是外接框中心 —— 徽标右上是细尖的星形，
   重量都在左下对勾，外接框居中会让整体看起来偏下 10%。
"""

import numpy as np
from PIL import Image

SRC = "/Users/tango/Developments/SportsHelper/DongKe/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
OUT = "/Users/tango/Developments/SportsHelper/DongKe/Assets.xcassets/LaunchMark.imageset"

PT = 180  # asset 点尺寸：iPhone 上占屏宽 34%（393pt），够醒目不喧宾夺主
MARK_RATIO = 0.74  # 标记占画布高度，给质心对齐留出上方空间

rgb = np.array(Image.open(SRC).convert("RGB")).astype(np.float32)
r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]

diff = np.maximum(g - r, b - r)  # 背景 76–134，白标 0
alpha = np.clip(1.0 - diff / 50.0, 0, 1)
alpha[alpha < 0.04] = 0.0

ys, xs = np.where(alpha > 0.2)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
sub = alpha[y0:y1, x0:x1]
h, w = sub.shape
print(f"标记 {w} x {h}（1024 画布内）")

yy, xx = np.mgrid[0:h, 0:w]
mass = sub.sum()
cx, cy = float((sub * xx).sum() / mass), float((sub * yy).sum() / mass)
print(f"质心在外接框内 ({cx:.1f}, {cy:.1f})，偏下 {cy - h / 2:+.1f} px")

mask = Image.fromarray((sub * 255).astype(np.uint8), mode="L")

SETS = {
    "LaunchMark": (14, 124, 102),       # Theme.tint      #0E7C66
    "LaunchMark-Dark": (52, 179, 154),  # Theme.tintDark  #34B39A
}

for stem, color in SETS.items():
    S = PT * 3  # 以 3x 为主版合成，1x/2x 由它缩下去，三档比例完全一致
    target_h = MARK_RATIO * S
    scale = target_h / h
    tw, th = round(w * scale), round(h * scale)
    placed = mask.resize((tw, th), Image.LANCZOS)

    canvas = Image.new("L", (S, S), 0)
    px = round(S / 2 - cx * scale)
    py = round(S / 2 - cy * scale)
    canvas.paste(placed, (px, py))

    solid = Image.new("RGBA", (S, S), color + (0,))
    solid.putalpha(canvas)

    print(f"{stem}: 画布 {PT}pt，标记 {tw / 3:.0f}x{th / 3:.0f}pt，边距 上{py} 下{S - py - th} px")

    solid.save(f"{OUT}/{stem}@3x.png")
    solid.resize((PT * 2, PT * 2), Image.LANCZOS).save(f"{OUT}/{stem}@2x.png")
    solid.resize((PT, PT), Image.LANCZOS).save(f"{OUT}/{stem}.png")

print("done")
