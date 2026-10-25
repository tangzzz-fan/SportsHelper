"""端到端验收：整句播报 → 切分 → 拼接 Qwen 音条 → 与 say 版对照。

切分逻辑照抄 `VoiceClipBank.segments`（最长匹配、跳过分隔符），
切不出来就是 `.fallback`——那种句子在真实运行时也会回落系统 TTS，这里直接报出来。
"""

import subprocess
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).parent
REPO = Path("/Users/tango/Developments/SportsHelper")
QWEN = REPO / ".scratch/offline-tts/assets/render"
SAY = REPO / "VoiceClips"
OUT = REPO / ".scratch/offline-tts/assets/concat"
SR = 22050
GAP_MS = 70

SEPARATORS = set("，、： :,\n")

SENTENCES = [
    "开始训练，共 9 组，3 个动作",
    "俯卧撑，第 1 组，共 3 组，10 次",
    "哑铃划船，第 1 组，每侧 12 次",
    "平板支撑，第 1 组，40 秒",
    "休息",
    "休息结束",
    "接下来",
    "完成 9 组，完成率 100%",
]


def fnv1a(text: str) -> str:
    h = 0xCBF29CE484222325
    for b in text.encode():
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def load_inventory() -> tuple[set[str], int]:
    tsv = Path(subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'],
                              capture_output=True, text=True).stdout.strip()) / "dk-clip-dump" / "inventory.tsv"
    phrases = {line.split("\t", 1)[1] for line in
               tsv.read_text(encoding="utf-8-sig").splitlines()}
    return phrases, max(len(p) for p in phrases)


def segments(text: str, phrases: set[str], longest: int) -> list[str] | None:
    chars = list(text)
    out, i = [], 0
    while i < len(chars):
        if chars[i] in SEPARATORS:
            i += 1
            continue
        upper = min(longest, len(chars) - i)
        found = None
        for length in range(upper, 0, -1):
            cand = "".join(chars[i : i + length])
            if cand in phrases:
                found = cand
                break
        if found is None:
            return None
        out.append(found)
        i += len(found)
    return out or None


def read(path: Path) -> np.ndarray | None:
    if not path.exists():
        return None
    x, _ = sf.read(str(path), dtype="float32")
    return x[:, 0] if x.ndim > 1 else x


def concat(parts: list[np.ndarray], gap_ms: int = GAP_MS) -> np.ndarray:
    gap = np.zeros(int(SR * gap_ms / 1000), dtype=np.float32)
    out = []
    for i, p in enumerate(parts):
        if i:
            out.append(gap)
        out.append(p)
    return np.concatenate(out)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    phrases, longest = load_inventory()

    for idx, sentence in enumerate(SENTENCES, 1):
        segs = segments(sentence, phrases, longest)
        if segs is None:
            print(f"[{idx}] ✘ 切不出来（运行时回落 TTS）: {sentence}")
            continue
        qwen = [read(QWEN / f"{fnv1a(s)}.wav") for s in segs]
        say = [read(SAY / f"{fnv1a(s)}.wav") for s in segs]
        missing = [s for s, q in zip(segs, qwen) if q is None]
        if missing:
            print(f"[{idx}] ✘ 缺 Qwen 音条 {missing}  : {sentence}")
            continue

        tag = f"{idx:02d}"
        qpath = OUT / f"{tag}-qwen.wav"
        sf.write(str(qpath), concat(qwen), SR, subtype="PCM_16")
        qdur = sf.info(str(qpath)).frames / SR

        line = f"[{idx}] {qdur:5.2f}s  {' + '.join(segs)}"
        if all(s is not None for s in say):
            spath = OUT / f"{tag}-say.wav"
            sf.write(str(spath), concat(say), SR, subtype="PCM_16")
            sdur = sf.info(str(spath)).frames / SR
            line += f"\n      say {sdur:5.2f}s  偏差 {(qdur - sdur) / sdur * 100:+.0f}%"
        print(line)

    # 整节课连听：开场 → 第一组 → 休息 → 下一组 → 结束
    parts = []
    for idx in (1, 2, 5, 7, 3, 8):
        p = OUT / f"{idx:02d}-qwen.wav"
        if p.exists():
            parts.append(read(p))
            parts.append(np.zeros(int(SR * 1.5), dtype=np.float32))
    if parts:
        whole = OUT / "99-整节课片段-qwen.wav"
        sf.write(str(whole), np.concatenate(parts), SR, subtype="PCM_16")
        print(f"\n连听 {whole.name}  {sf.info(str(whole)).frames / SR:.1f}s")
    print(f"输出 {OUT}")


if __name__ == "__main__":
    main()
