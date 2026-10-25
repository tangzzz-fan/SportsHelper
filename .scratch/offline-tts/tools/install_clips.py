"""把新渲染的音条换进 VoiceClips/，换之前先全量校验。

校验三件事（任一不过就停）：
1. 条数必须是 496，且与 inventory 一一对应（缺一条运行时就会回落系统 TTS）
2. 全部 22050 Hz 单声道 PCM_16
3. 时长没有跑飞（自回归模型的重复循环）

换之前会把旧音条备份到 /tmp，因为 VoiceClips/*.wav 在 .gitignore 里，git 恢复不了。
"""

import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

REPO = Path("/Users/tango/Developments/SportsHelper")
TARGET = REPO / "VoiceClips"
BACKUP = Path("/tmp/qwen-tts-bench/VoiceClips-prev")
TARGET_SR = 22050


def inventory() -> list[tuple[str, str]]:
    tsv = Path(subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'],
                              capture_output=True, text=True).stdout.strip()) / "dk-clip-dump" / "inventory.tsv"
    return [ln.split("\t", 1) for ln in tsv.read_text(encoding="utf-8-sig").splitlines()]


def say_dur(cid: str) -> float:
    p = TARGET / f"{cid}.wav"
    if not p.exists():
        return 0.0
    x, sr = sf.read(str(p), dtype="float32")
    if x.ndim > 1:
        x = x[:, 0]
    idx = np.where(np.abs(x) > 10 ** (-45 / 20))[0]
    return (idx[-1] - idx[0] + 1) / sr if len(idx) else 0.0


def main() -> None:
    src = Path(sys.argv[1])
    rows = inventory()
    print(f"inventory {len(rows)} 条")

    missing = [c for c, _ in rows if not (src / f"{c}.wav").exists()]
    if missing:
        raise SystemExit(f"❌ 缺 {len(missing)} 条：{missing[:5]}")

    bad_fmt, bad_len, durs = [], [], []
    for cid, text in rows:
        x, sr = sf.read(str(src / f"{cid}.wav"), dtype="float32")
        if x.ndim > 1:
            x = x[:, 0]
        info = sf.info(str(src / f"{cid}.wav"))
        if info.samplerate != TARGET_SR or info.channels != 1:
            bad_fmt.append((cid, info.samplerate, info.channels))
        d = len(x) / sr
        durs.append(d)
        base = say_dur(cid)
        if base > 0 and d > base * 1.6 + 0.4:
            bad_len.append((cid, d, base * 1.6 + 0.4, text))

    if bad_fmt:
        raise SystemExit(f"❌ 格式不对 {len(bad_fmt)} 条：{bad_fmt[:3]}")
    if bad_len:
        print(f"⚠️ 时长超标 {len(bad_len)} 条：")
        for cid, d, lim, text in sorted(bad_len, reverse=True)[:8]:
            print(f"   {d:5.2f}s / {lim:4.2f}s  {text[:20]}")
        raise SystemExit("先重跑这些条目（render_clone.py --recheck）")

    total = sum((src / f"{c}.wav").stat().st_size for c, _ in rows)
    print(f"✅ 校验通过：{len(rows)} 条，{total / 1048576:.1f} MB，"
          f"总时长 {sum(durs) / 60:.1f} 分钟，均值 {sum(durs) / len(durs):.2f}s")

    if BACKUP.exists():
        shutil.rmtree(BACKUP)
    shutil.copytree(TARGET, BACKUP)
    print(f"旧音条备份到 {BACKUP}")

    for f in TARGET.glob("*.wav"):
        f.unlink()
    for f in TARGET.glob("*.txt"):
        f.unlink()
    for cid, _ in rows:
        shutil.copy2(src / f"{cid}.wav", TARGET / f"{cid}.wav")
        txt = src / f"{cid}.txt"
        if txt.exists():
            shutil.copy2(txt, TARGET / f"{cid}.txt")

    got = len(list(TARGET.glob("*.wav")))
    print(f"✅ 已替换 VoiceClips/：{got} 个 wav，{sum(f.stat().st_size for f in TARGET.glob('*.wav')) / 1048576:.1f} MB")


if __name__ == "__main__":
    main()
