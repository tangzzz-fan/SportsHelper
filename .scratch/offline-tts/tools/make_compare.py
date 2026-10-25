"""生成对比包：同一批播报，系统 say 版 vs Qwen 版，文件名直接写明是谁。

为什么要这个脚本：之前两次推给用户的文件顺序不一样（一次 say 在前，一次 Qwen 在前），
听串了。这里固定「1=系统 2=Qwen」的编号，并且同一句话长度相当，便于直接对比。
"""

from pathlib import Path

import numpy as np
import soundfile as sf

REPO = Path("/Users/tango/Developments/SportsHelper")
QWEN = REPO / ".scratch/offline-tts/assets/render"
SAY = REPO / "VoiceClips"
OUT = REPO / ".scratch/offline-tts/assets/compare"
SR = 22050
GAP_MS = 70


def fnv1a(text: str) -> str:
    h = 0xCBF29CE484222325
    for b in text.encode():
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def read(path: Path) -> np.ndarray:
    x, _ = sf.read(str(path), dtype="float32")
    x = x[:, 0] if x.ndim > 1 else x
    if len(x) == 0:
        raise SystemExit(f"空音频 {path}")
    return x


def concat(parts: list[np.ndarray], gap_ms: int = GAP_MS) -> np.ndarray:
    gap = np.zeros(int(SR * gap_ms / 1000), dtype=np.float32)
    out = []
    for i, p in enumerate(parts):
        if i:
            out.append(gap)
        out.append(p)
    return np.concatenate(out)


# 四段真实播报，覆盖最常听到的形态
SENTENCES = {
    "1-动作播报": ["俯卧撑", "第 1 组", "共 3 组", "10 次"],
    "2-开场": ["开始训练", "共 9 组", "3 个动作"],
    "3-每侧动作": ["哑铃划船", "第 1 组", "每侧 12 次"],
    "4-结束": ["完成 9 组", "完成率 100%"],
}

# 一节课的片段序列，用来听整体节奏
LESSON = [
    ["开始训练", "共 9 组", "3 个动作"],
    ["俯卧撑", "第 1 组", "共 3 组", "10 次"],
    ["休息"],
    ["接下来"],
    ["俯卧撑", "第 2 组", "共 3 组", "10 次"],
    ["休息"],
    ["接下来"],
    ["哑铃划船", "第 1 组", "每侧 12 次"],
    ["休息"],
    ["接下来"],
    ["平板支撑", "第 1 组", "40 秒"],
    ["休息"],
    ["完成 9 组", "完成率 100%"],
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    for name, segs in SENTENCES.items():
        say = concat([read(SAY / f"{fnv1a(s)}.wav") for s in segs])
        qwen = concat([read(QWEN / f"{fnv1a(s)}.wav") for s in segs])
        sf.write(str(OUT / f"{name}-A-系统say.wav"), say, SR, subtype="PCM_16")
        sf.write(str(OUT / f"{name}-B-Qwen.wav"), qwen, SR, subtype="PCM_16")
        print(f"{name}: say {len(say) / SR:5.2f}s  qwen {len(qwen) / SR:5.2f}s  "
              f"偏差 {(len(qwen) - len(say)) / len(say) * 100:+.0f}%")

    # 整节课：两版各一份，中间加 1.5 秒当动作时间
    for tag, src in (("A-系统say", SAY), ("B-Qwen", QWEN)):
        parts = []
        for segs in LESSON:
            parts.append(concat([read(src / f"{fnv1a(s)}.wav") for s in segs]))
            parts.append(np.zeros(int(SR * 1.5), dtype=np.float32))
        whole = np.concatenate(parts)
        sf.write(str(OUT / f"5-整节课-{tag}.wav"), whole, SR, subtype="PCM_16")
        print(f"5-整节课-{tag}: {len(whole) / SR:.1f}s")

    print(f"\n输出 {OUT}")


if __name__ == "__main__":
    main()
