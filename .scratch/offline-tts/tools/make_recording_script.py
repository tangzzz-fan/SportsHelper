"""生成配音录音稿：把 VoiceClipBank.inventory 按语义分组，附语气提示与参考时长。

产物是一份给配音演员的 CSV —— 按字典序给 496 条是不可用的，必须按「这句话在课上
干什么用」分组，每一组配一条语气提示。
"""

import csv
import re
import subprocess
from pathlib import Path

REPO = Path("/Users/tango/Developments/SportsHelper")
SAY = REPO / "VoiceClips"
OUT = REPO / "docs" / "recording-script.csv"

# 分组顺序 = 建议的录制顺序：先短后长，先把语气定下来再录长句
GROUPS = [
    ("固定短语", "整节课的骨架，只有 4 条，先录这 4 条定语气"),
    ("动作名", "念清楚就行，不要用力过猛，它后面还跟着组数"),
    ("组数与进度", "数字要干脆；「第 N 组」和「共 N 组」通常连着念"),
    ("次数", "干脆，像报数"),
    ("时长", "干脆，注意「分」和「分钟」是两个不同的词"),
    ("距离", "干脆"),
    ("完成率", "结束时念，可以带一点收尾的满意感"),
    ("动作数量", "开场用，一口气带过"),
    ("单个数字", "只有一个数字，短促"),
    ("动作要点", "最长的一组，像教练在旁边提醒，稍慢但不拖"),
]

TONE = {
    "开始训练": "有力、启动。像按下秒表那一刻",
    "休息": "放松、平缓，把气放下来",
    "休息结束": "提气、准备继续",
    "接下来": "提示，轻一点，不要重读",
}

# 没写专有提示的，用所属分组的一句话
GROUP_TONE = {
    "固定短语": "",
    "动作名": "念清楚、不拖长。后面还跟着组数，收尾别下坠",
    "组数与进度": "数字干脆。「第 N 组」收尾略平，不要念成句号",
    "次数": "干脆，像报数",
    "时长": "干脆。注意「分」和「分钟」是两个不同的词",
    "距离": "干脆",
    "完成率": "结束时念，可以带一点收尾的满意感",
    "动作数量": "一口气带过，不顿",
    "单个数字": "短促，只念字面",
    "动作要点": "像教练在旁边提醒，稍慢但不拖",
}

# 同一分组内的模板顺序，按课堂语境排（先报第几组，再说共几组）
TEMPLATE_ORDER = {
    "开始训练": 0, "休息": 1, "休息结束": 2, "接下来": 3,
    "第 #组": 10, "共 #组": 11, "完成 #组": 12, "另有 #组加练": 13,
}

PATTERNS = [
    (re.compile(r"^第 \d+ 组$"), "组数与进度"),
    (re.compile(r"^共 \d+ 组$"), "组数与进度"),
    (re.compile(r"^完成 \d+ 组$"), "组数与进度"),
    (re.compile(r"^另有 \d+ 组加练$"), "组数与进度"),
    (re.compile(r"^\d+ 次$|^每侧 \d+ 次$"), "次数"),
    (re.compile(r"^\d+ 秒$|^\d+ 分$|^\d+ 分钟$"), "时长"),
    (re.compile(r"^\d+ 米$|^\d+ 公里$|^每侧 \d+ 公里$"), "距离"),
    (re.compile(r"^完成率 \d+%$"), "完成率"),
    (re.compile(r"^\d+ 个动作$"), "动作数量"),
    (re.compile(r"^\d+$"), "单个数字"),
]


def speech_dur(path: Path) -> float:
    import numpy as np
    import soundfile as sf

    if not path.exists():
        return 0.0
    x, sr = sf.read(str(path), dtype="float32")
    if x.ndim > 1:
        x = x[:, 0]
    idx = np.where(np.abs(x) > 10 ** (-45 / 20))[0]
    return (idx[-1] - idx[0] + 1) / sr if len(idx) else 0.0


def catalog_names_and_cues() -> tuple[set[str], set[str]]:
    """从 Swift 源码取动作名与要点——不要另抄一份清单。"""
    names, cues = set(), set()
    for f in (REPO / "DongKeCore/Models").glob("ExerciseCatalog*.swift"):
        src = f.read_text()
        for m in re.finditer(r'name:\s*"([^"]+)"', src):
            names.add(m.group(1))
        for m in re.finditer(r"cues:\s*\[(.*?)\]", src, re.S):
            cues.update(re.findall(r'"([^"]+)"', m.group(1)))
    return names, cues


def classify(text: str, names: set[str], cues: set[str]) -> str:
    if text in ("开始训练", "休息", "休息结束", "接下来"):
        return "固定短语"
    for pattern, group in PATTERNS:
        if pattern.match(text):
            return group
    if text in names:
        return "动作名"
    if text in cues:
        return "动作要点"
    raise SystemExit(f"分不出组：{text!r}")


def order_key(text: str) -> tuple[int, str, int, str]:
    """组内排序：同模板的连在一起，数字按大小。

    不这么排的话「第 1 组、第 10 组、第 11 组、第 2 组…」会把配音演员念疯。
    模板之间也有顺序：先「第 N 组」再「共 N 组」，符合课堂上的说话顺序。
    """
    template = re.sub(r"\d+", "#", text)
    m = re.search(r"\d+", text)
    return TEMPLATE_ORDER.get(template, 50), template, int(m.group()) if m else 0, text


def main() -> None:
    tsv = Path(subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'],
                              capture_output=True, text=True).stdout.strip()) / "dk-clip-dump" / "inventory.tsv"
    rows = [line.split("\t", 1) for line in tsv.read_text(encoding="utf-8-sig").splitlines()]
    names, cues = catalog_names_and_cues()

    grouped: dict[str, list[tuple[str, str]]] = {g: [] for g, _ in GROUPS}
    for cid, text in rows:
        grouped[classify(text, names, cues)].append((cid, text))
    for g in grouped:
        grouped[g].sort(key=lambda pair: order_key(pair[1]))

    total = sum(len(v) for v in grouped.values())
    print(f"共 {total} 条")
    for g, _ in GROUPS:
        print(f"  {g:<10} {len(grouped[g]):>3} 条")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    idx = 0
    with OUT.open("w", newline="", encoding="utf-8-sig") as fh:
        w = csv.writer(fh)
        w.writerow(["序号", "分组", "播报原文", "语气提示", "参考时长(秒)", "文件名"])
        for group, _ in GROUPS:
            for cid, text in grouped[group]:
                idx += 1
                w.writerow([
                    idx,
                    group,
                    text,
                    TONE.get(text, "") or GROUP_TONE[group],
                    f"{speech_dur(SAY / f'{cid}.wav'):.2f}",
                    f"{idx:03d}_{cid}.wav",
                ])
    print(f"\n写入 {OUT}")


if __name__ == "__main__":
    main()
