"""检查录音语料是否覆盖动作目录。

为什么需要
----------
播报走预录音条库（`ClipSpeechRenderer`），**不是实时 TTS**。缺一条就 fallback 到
系统 TTS，音色会跳——用户听得出"这句话不是同一个人说的"。

而语料是按目录录的：每个动作 1 条动作名 + 3 条动作要点。所以**加一个动作必须同时加 4 条语料**。
这个脚本把"漏了没"变成可执行检查。

    python3 Tools/check_voice_coverage.py

退出码非零表示有缺口。
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ["", "Upper", "Core", "Lower"]
SCRIPT = ROOT / "docs/recording-script.csv"


def load_catalog() -> list[tuple[str, str, list[str]]]:
    """从 Swift 目录文件里抽 (id, name, cues)。"""
    text = "".join(
        (ROOT / f"DongKeCore/Models/ExerciseCatalog{s}.swift").read_text(encoding="utf-8")
        for s in CATALOG
    )
    out = []
    for m in re.finditer(r'ExerciseEntry\((.*?)\n        \)', text, re.S):
        block = m.group(1)
        eid = re.search(r'id:\s*"([a-z0-9_]+)"', block)
        name = re.search(r'name:\s*"([^"]+)"', block)
        cues = re.search(r'cues:\s*\[([^\]]*)\]', block, re.S)
        if not (eid and name and cues):
            continue
        out.append((eid.group(1), name.group(1), re.findall(r'"([^"]+)"', cues.group(1))))
    return out


def fnv1a64(s: str) -> str:
    h = 0xCBF29CE484222325
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def main() -> None:
    catalog = load_catalog()
    rows = list(csv.DictReader(open(SCRIPT, encoding="utf-8-sig")))
    by_text = {r["播报原文"]: r for r in rows}

    missing_name, missing_cue, bad_hash = [], [], []
    for eid, name, cues in catalog:
        if name not in by_text:
            missing_name.append((eid, name))
        for c in cues:
            if c not in by_text:
                missing_cue.append((eid, c))

    # 文件名里的 hash 必须等于 clipId(播报原文)，否则运行时找不到这个文件
    for r in rows:
        want = f"{r['文件名'].split('_')[0]}_{fnv1a64(r['播报原文'])}.wav"
        if r["文件名"] != want:
            bad_hash.append((r["序号"], r["播报原文"], r["文件名"], want))

    names = {name for _, name, _ in catalog}
    cues_all = {c for _, _, cs in catalog for c in cs}
    orphans = [r["播报原文"] for r in rows
               if r["分组"] == "动作名" and r["播报原文"] not in names]

    print(f"目录 {len(catalog)} 个动作 · 语料 {len(rows)} 条")
    print(f"  缺动作名   {len(missing_name)}")
    print(f"  缺动作要点 {len(missing_cue)}")
    print(f"  文件名 hash 不符 {len(bad_hash)}")
    print(f"  语料里多出的动作名 {len(orphans)}")

    for label, items in [("缺动作名", missing_name), ("缺动作要点", missing_cue)]:
        if items:
            print(f"\n{label}：")
            for a, b in items[:12]:
                print(f"  {a:28s} {b}")
            if len(items) > 12:
                print(f"  …还有 {len(items) - 12} 条")

    if bad_hash:
        print("\n文件名 hash 不符：")
        for seq, text, got, want in bad_hash[:8]:
            print(f"  #{seq} {text!r}\n    现在 {got}\n    应为 {want}")

    if orphans:
        print(f"\n语料里多出（目录已删但音频还在）：{orphans[:8]}")

    total_missing = len(missing_name) + len(missing_cue) + len(bad_hash)
    print(f"\n{'✅ 语料与目录一致' if total_missing == 0 else f'❌ {total_missing} 处需要补'}")
    sys.exit(0 if total_missing == 0 else 1)


if __name__ == "__main__":
    main()
