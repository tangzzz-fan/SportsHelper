"""测「进程起来 → 首帧画出内容」的真实耗时。

启动图消失的时机只由这个时间决定，所以量它而不是量截图。
判定靠 app 里埋的两条时间戳：init 第一行 + RootView 首次 onAppear。
"""

import os
import subprocess
import time

UDID = "1FA063ED-38A4-4386-84C8-4C79229CC10F"
BUNDLE = "app.dongke.ios"
APP = "/tmp/dk-shot/Build/Products/Debug-iphonesimulator/DongKe.app"
LOG = "/tmp/launchlog.txt"


def run(cmd, timeout=60, env=None):
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        pass


def once(label, install):
    run(["xcrun", "simctl", "terminate", UDID, BUNDLE], 20)
    if install:
        run(["xcrun", "simctl", "uninstall", UDID, BUNDLE], 40)
        run(["xcrun", "simctl", "install", UDID, APP], 120)

    logfile = open(LOG, "w")
    stream = subprocess.Popen(
        ["xcrun", "simctl", "spawn", UDID, "log", "stream",
         "--predicate", 'subsystem == "app.dongke.ios" AND category == "launch"',
         "--style", "compact"],
        stdout=logfile, stderr=subprocess.STDOUT,
    )
    time.sleep(2.0)

    env = os.environ.copy()
    env["SIMCTL_CHILD_DK_SEED_DEMO"] = "1"
    run(["xcrun", "simctl", "launch", UDID, BUNDLE], 30, env=env)
    time.sleep(4.0)

    stream.terminate()
    try:
        stream.wait(timeout=8)
    except subprocess.TimeoutExpired:
        stream.kill()
    logfile.close()

    lines = [l for l in open(LOG).read().splitlines() if "first-frame" in l]
    print(f"{label}: {lines[-1].split('first-frame')[-1].strip() if lines else '未抓到'}")


once("冷启动（重装）", True)
once("热启动", False)
once("热启动再来一次", False)
