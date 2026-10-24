"""本地预览：不编译 Swift，直接用 PIL 画轮廓，用于快速迭代姿态坐标。

用法：python3 Tools/FigureDraw/preview.py [catalogId ...]
产物：/tmp/figure-draw/<catalogId>-fN.png
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import poses

OUT = "/tmp/figure-draw"
SIDE = 420
STROKE = 2.4
INK = (28, 38, 35)


def render(frames, name, side=SIDE, stroke=STROKE):
    os.makedirs(OUT, exist_ok=True)
    all_pts = [p for f in frames for c in f for p in c]
    minx = min(p[0] for p in all_pts); maxx = max(p[0] for p in all_pts)
    miny = min(p[1] for p in all_pts); maxy = max(p[1] for p in all_pts)
    w, h = maxx - minx, maxy - miny
    pad = side * 0.08
    scale = min((side - pad * 2) / w, (side - pad * 2) / h)
    ox = (side - w * scale) / 2 - minx * scale
    oy = (side - h * scale) / 2 - miny * scale
    width = max(1, int(round(stroke * scale / 2.44)))

    for i, frame in enumerate(frames):
        img = Image.new("RGB", (side, side), (255, 255, 255))
        d = ImageDraw.Draw(img)
        for contour in frame:
            pts = [(x * scale + ox, y * scale + oy) for x, y in contour]
            if len(pts) < 2:
                continue
            d.line(pts + [pts[0]], fill=INK, width=width, joint="curve")
        img.save(f"{OUT}/{name}-f{i + 1}.png")


def main():
    names = sys.argv[1:] or list(poses.POSES)
    for n in names:
        fn, motion = poses.POSES[n]
        frames = fn()
        render(frames, n)
        print(f"{n}: {len(frames)} 帧 / {motion} / {sum(len(f) for f in frames)} 轮廓")


if __name__ == "__main__":
    main()
