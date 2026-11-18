"""从 AppIcon 抠出品牌标记，生成启动屏要的两个资产：LaunchMark 与 LaunchGlow。

启动屏是静态的：storyboard 里的 view 只能填纯色或贴图，没有 CAGradientLayer。
所以「不是一片平涂绿」拆成三层来做：

    LaunchBackground（colorset，纯色，0 字节）
  + LaunchGlow（一张小尺寸径向光晕，铺满全屏，给画面呼吸感）
  + LaunchMark（从 AppIcon 抠出的白色标记，居中）

不烘一整张全屏渐变图，是因为渐变的量化条纹宽度只取决于「色阶跨度 ÷ 画布高度」，
跟分辨率无关——低分辨率烘出来再放大，色带表现和 @3x 直出一模一样。
既然如此就没必要背一张 150KB 的全屏图：光晕层本身是模糊的，拉伸无损，
512px 的源图放大到 @3x 只多几 KB。

四个判据上的坑：

1. 抠图用色差、不用亮度。图标背景是绿（G-R≈100），标记是白（G-R≈0）；
   但标记周围有一圈白光晕，最亮处 (199,238,230) 的 G-R 已经掉到 39，
   用 /50 的软阈值会把它当成 22% 不透明的标记，边缘起一圈毛。
   阈值压到 25 就切干净了——反正降采样到 300px 时 LANCZOS 会补回抗锯齿。

2. 对齐用「不透明面积质心」、不用外接框中心。徽标右上是细尖的四角星，
   重量全压在左下对勾，外接框居中会让整体看着偏下。

3. 光晕的边缘必须真的落到 alpha=0。留一点点残余就是一个可见的矩形框，
   贴在纯色底上尤其明显。

4. 光晕用同色相更亮的绿、不用白。白光晕会把品牌绿洗成灰绿，
   放大到全屏后整块颜色发脏。
"""

import json
import os

import numpy as np
from PIL import Image

ROOT = "/Users/tango/Developments/SportsHelper"
SRC = f"{ROOT}/DongKe/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
ASSETS = f"{ROOT}/DongKe/Assets.xcassets"

MARK_PT = 104        # 标记边长，占 393pt 屏宽的 26%
MARK_RATIO = 0.86    # 标记占画布高，剩下的高度留给质心对齐
GLOW_PX = 256        # 光晕源图边长。只出 @1x 一档：光晕本身没有细节，
                     # 放大到 @3x 只是把 alpha 台阶摊宽，颜色差仍在 1/255 量级。
GLOW_CENTER = (0.50, 0.42)   # 光心，光学居中偏上

# 光晕用哪一档绿：底色之上只提亮一档，不做成「一团白光」
GLOW_TINT = {"light": (48, 196, 166), "dark": (28, 104, 88)}
# 半径与峰值：0.62/0.62 太弥散，标记周围没有落点；收到 0.46/0.80 才有了焦点。
# 启动屏只露 0.3 秒，一眼认出比含蓄更要紧。
GLOW_RADIUS = 0.46
GLOW_PEAK = {"light": 0.86, "dark": 0.78}
# 衰减指数。平方衰减在 t=0.5 时已经掉到 0.25，实机上亮区只剩设计半径的 1/3，
# 量出来中心和边缘只差 13/255 —— 而 AppIcon 自己差 102。改成 1.4 次方把光摊开。
GLOW_FALLOFF = 1.4
MARK_TINT = {"light": (255, 255, 255), "dark": (102, 214, 188)}


def cut_mark() -> Image.Image:
    """从 1024 图标切出标记，返回灰度 alpha。"""
    rgb = np.array(Image.open(SRC).convert("RGB")).astype(np.float32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    diff = np.maximum(g - r, b - r)
    alpha = np.clip(1.0 - diff / 25.0, 0, 1)
    alpha[alpha < 0.04] = 0.0

    ys, xs = np.where(alpha > 0.5)
    sub = alpha[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    print(f"标记 {sub.shape[1]}x{sub.shape[0]} px（1024 画布内）")
    return Image.fromarray((sub * 255).astype(np.uint8), mode="L")


def mark_canvas(mask: Image.Image, size_px: int) -> Image.Image:
    """把标记按质心放进正方形画布，返回 L 通道。"""
    h, w = mask.size
    scale = (MARK_RATIO * size_px) / h
    tw, th = round(w * scale), round(h * scale)
    placed = mask.resize((tw, th), Image.LANCZOS)

    arr = np.array(placed).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:th, 0:tw]
    cx, cy = float((arr * xx).sum() / arr.sum()), float((arr * yy).sum() / arr.sum())

    canvas = Image.new("L", (size_px, size_px), 0)
    canvas.paste(placed, (round(size_px / 2 - cx), round(size_px / 2 - cy)))
    print(f"  {size_px}px：标记 {tw}x{th}，质心 ({cx:.0f},{cy:.0f})")
    return canvas


def glow(scheme: str) -> Image.Image:
    """径向光晕：中心 peak、边缘严格 0。"""
    n = GLOW_PX
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    cx, cy = GLOW_CENTER[0] * n, GLOW_CENTER[1] * n
    r = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / (n * GLOW_RADIUS)
    t = np.clip(r, 0.0, 1.0)

    # 幂衰减，中心平缓和、边缘收得干净
    a = ((1.0 - t) ** GLOW_FALLOFF) * GLOW_PEAK[scheme]
    a[t >= 1.0] = 0.0

    img = Image.new("RGBA", (n, n), GLOW_TINT[scheme] + (0,))
    img.putalpha(Image.fromarray(np.rint(a * 255).astype(np.uint8), mode="L"))
    return img


def filename(stem: str, scheme: str, scale: int) -> str:
    return f"{stem}-{scheme}@{scale}x.png" if scale > 1 else f"{stem}-{scheme}.png"


def write_imageset(name: str, entries: list[dict]) -> None:
    path = f"{ASSETS}/{name}.imageset"
    os.makedirs(path, exist_ok=True)
    for entry in entries:
        entry.pop("image").save(f"{path}/{entry['filename']}")
    with open(f"{path}/Contents.json", "w") as fh:
        json.dump({"images": entries, "info": {"author": "xcode", "version": 1}}, fh, indent=2)
        fh.write("\n")
    total = sum(os.path.getsize(f"{path}/{e['filename']}") for e in entries)
    print(f"→ {name}.imageset（{len(entries)} 个文件，{total / 1024:.1f} KB）")


def main():
    mask = cut_mark()

    mark_entries, glow_entries = [], []
    for scheme in ("light", "dark"):
        print(f"{scheme}")
        for scale in (1, 2, 3):
            alpha = mark_canvas(mask, MARK_PT * scale)
            solid = Image.new("RGBA", alpha.size, MARK_TINT[scheme] + (0,))
            solid.putalpha(alpha)
            entry = {"filename": filename("LaunchMark", scheme, scale),
                     "idiom": "universal", "scale": f"{scale}x", "image": solid}
            if scheme == "dark":
                entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
            mark_entries.append(entry)

        base = glow(scheme)
        entry = {"filename": filename("LaunchGlow", scheme, 1),
                 "idiom": "universal", "scale": "1x", "image": base}
        if scheme == "dark":
            entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        glow_entries.append(entry)

    write_imageset("LaunchMark", mark_entries)
    write_imageset("LaunchGlow", glow_entries)
    print("done")


if __name__ == "__main__":
    main()
