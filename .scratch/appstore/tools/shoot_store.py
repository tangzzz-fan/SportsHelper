"""按 App Store 6.9" 规格抓取各页面截图（1320×2868）。

上一轮的三个错，这次都堵上：

1. **每屏都要重新 seed**。每屏都卸载重装是为了清掉上一次留下的训练记录，
   但 `DK_SEED_DEMO` 只在 profile 为空时写档案——只给第一屏加，后面几屏
   就全退回 onboarding（「计划」那张截出来是「先认识一下」，就是这么来的）。
2. **判「已经画出内容」要看暗像素，不能看品牌绿**。首页那颗绿色「开始训练」
   按钮就在画面中部，按绿色面积判会把内容页误判成启动屏，白等到 30 秒超时。
   标题文字是内容页独有的黑色像素，这个更可靠。
3. **仍然要等画面稳定**。内容出来不等于画完了，动作插图是异步铺的。
"""

import os
import shutil
import subprocess
import time
from pathlib import Path

import numpy as np
from PIL import Image

UDID = "1FA063ED-38A4-4386-84C8-4C79229CC10F"
BUNDLE = "app.dongke.ios"
APP = "/tmp/dk-shot/Build/Products/Debug-iphonesimulator/DongKe.app"
OUT = Path("/tmp/shots3")
PROBE = "/tmp/_probe.png"

SHOTS = [
    ("1-今日", "", {"DK_SEED_SESSION": ""}),
    ("2-训练中", "workout", {}),
    ("3-计划", "plan", {}),
    ("4-动作库", "library", {}),
    ("5-总结", "summary", {}),
    ("6-记录", "history", {"DK_SEED_SESSION": "1"}),
]


def run(cmd, timeout=60, env=None):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
        return r.returncode, (r.stdout or "").strip(), (r.stderr or "").strip()
    except subprocess.TimeoutExpired:
        return "timeout", "", ""


def grab():
    run(["xcrun", "simctl", "io", UDID, "screenshot", PROBE], 40)
    return np.asarray(Image.open(PROBE).convert("L"), dtype=np.int16)


def dark_ratio(img):
    """状态栏自带黑色时间，先裁掉；内容页才有大片黑色标题。"""
    return float((img[150:, :] < 110).mean())


def wait_content(max_wait=25.0):
    """固定等 8 秒再判断。

    不能「一看到内容就截」：像 `DK_PREVIEW=workout` 这种是靠 `fullScreenCover`
    弹出来的，首页会先渲染出来（有暗像素、也静止），此时截图拿到的是首页而不是训练页。
    冷启动 + cover 动画实测在 4–6 秒之间才落定，8 秒留够余量。
    """
    started = time.time()
    prev = None
    while time.time() - started < max_wait:
        time.sleep(8.0 if prev is None else 1.2)
        cur = grab()
        if prev is not None and float(np.abs(cur - prev).mean()) < 0.6:
            return True, time.time() - started
        prev = cur
    return False, time.time() - started


OUT.mkdir(parents=True, exist_ok=True)
run(["xcrun", "simctl", "status_bar", UDID, "override",
     "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100",
     "--cellularBars", "4", "--wifiBars", "3"], 30)

for name, preview, extra in SHOTS:
    run(["xcrun", "simctl", "terminate", UDID, BUNDLE], 20)
    run(["xcrun", "simctl", "uninstall", UDID, BUNDLE], 40)
    run(["xcrun", "simctl", "install", UDID, APP], 120)

    env = os.environ.copy()
    env["SIMCTL_CHILD_DK_SEED_DEMO"] = "1"  # 每屏都 seed，否则退回 onboarding
    # 临时通知授权：不弹系统框，但状态算作已授权，首页那条「还没开启通知权限」
    # 的横幅就不会出现。截图里那种横幅会让 app 看起来在索要权限。
    env["SIMCTL_CHILD_DK_REQUEST_PROVISIONAL"] = "1"
    if preview:
        env["SIMCTL_CHILD_DK_PREVIEW"] = preview
    for k, v in extra.items():
        if v:
            env["SIMCTL_CHILD_" + k] = v

    code, _, err = run(["xcrun", "simctl", "launch", UDID, BUNDLE], 40, env=env)
    ok, waited = wait_content()
    shutil.copy(PROBE, OUT / f"{name}.png")
    print(f"{name:<8} launch={code} 内容就绪={ok} 用时={waited:.1f}s")

run(["xcrun", "simctl", "terminate", UDID, BUNDLE], 20)
print("done ->", OUT)
