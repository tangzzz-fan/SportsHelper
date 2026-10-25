"""渲染一整句播报，按 VoiceClipBank 的切分规则拼接，与 say 版对比。

单条音条好听不代表能用——一节课听到的是「俯卧撑 / 第 2 组 / 共 3 组 / 10 次」
拼起来的那一句。所以这里只做拼接后的整句。
"""

import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

HERE = Path(__file__).parent
REPO = Path("/Users/tango/Developments/SportsHelper")
OUT = HERE / "concat"
GAP_MS = 70  # 与 ClipSpeechRenderer 的段间静音一致
SR = 24000

# 每句 = 一段播报，切成 VoiceClipBank 里的音条
SENTENCES = {
    "A-动作播报": ["俯卧撑", "第 2 组", "共 3 组", "10 次"],
    "B-开场": ["开始训练", "共 9 组", "3 个动作"],
    "C-过渡": ["休息", "休息结束"],
    "D-要点": ["平板支撑", "收紧臀部把髋顶到躯干成一条线，别用腰反弓"],
}


def fnv1a(text: str) -> str:
    h = 0xCBF29CE484222325
    for b in text.encode():
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def trim_silence(x: np.ndarray, thresh_db: float = -45.0) -> np.ndarray:
    th = 10 ** (thresh_db / 20)
    idx = np.where(np.abs(x) > th)[0]
    return x[idx[0] : idx[-1] + 1] if len(idx) else x


def load_say(phrase: str) -> np.ndarray | None:
    p = REPO / "VoiceClips" / f"{fnv1a(phrase)}.wav"
    if not p.exists():
        return None
    x, sr = sf.read(str(p), dtype="float32")
    if x.ndim > 1:
        x = x[:, 0]
    return x


def concat(parts: list[np.ndarray], gap_ms: int = GAP_MS) -> np.ndarray:
    gap = np.zeros(int(SR * gap_ms / 1000), dtype=np.float32)
    out = []
    for i, p in enumerate(parts):
        if i:
            out.append(gap)
        out.append(p)
    return np.concatenate(out)


def main() -> None:
    from qwen_tts import Qwen3TTSModel

    speakers = sys.argv[1:] or ["Serena"]
    OUT.mkdir(parents=True, exist_ok=True)

    phrases = sorted({p for segs in SENTENCES.values() for p in segs} | {"接下来"})
    print(f"需要 {len(phrases)} 个片段 × {len(speakers)} 个音色", flush=True)

    model = Qwen3TTSModel.from_pretrained(
        str(HERE / "model"), device_map="mps", dtype=torch.float32
    )

    cache: dict[tuple[str, str], np.ndarray] = {}
    cache_dir = HERE / "cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    for spk in speakers:
        for ph in phrases:
            cpath = cache_dir / f"{spk}-{fnv1a(ph)}.npy"
            if cpath.exists():
                cache[(spk, ph)] = np.load(str(cpath))
                print(f"  {spk:<9} 缓存命中  {ph}", flush=True)
                continue
            t0 = time.perf_counter()
            wavs, sr = model.generate_custom_voice(text=ph, speaker=spk, language="Chinese")
            x = np.asarray(wavs[0], dtype=np.float32)
            if x.ndim > 1:
                x = x[:, 0]
            cache[(spk, ph)] = x
            np.save(str(cpath), x)
            print(
                f"  {spk:<9} {len(x) / sr:5.2f}s ({time.perf_counter() - t0:5.1f}s) {ph}",
                flush=True,
            )

    print("\n拼接：", flush=True)
    for name, segs in SENTENCES.items():
        say_parts = []
        for ph in segs:
            x = load_say(ph)
            if x is not None:
                say_parts.append(x)
        if len(say_parts) == len(segs):
            sf.write(OUT / f"{name}-say.wav", concat(say_parts), SR)
            print(f"  {name}-say.wav", flush=True)
        else:
            print(f"  {name}: say 缺片段，跳过", flush=True)

        for spk in speakers:
            parts = [trim_silence(cache[(spk, ph)]) for ph in segs]
            sf.write(OUT / f"{name}-{spk}.wav", concat(parts), SR)
            print(f"  {name}-{spk}.wav", flush=True)

    # 一条里三句连听，模拟真实节奏：动作播报 → 休息 → 休息结束
    for spk in speakers:
        parts = []
        for ph in SENTENCES["A-动作播报"]:
            parts.append(trim_silence(cache[(spk, ph)]))
        parts.append(np.zeros(SR, dtype=np.float32))  # 1 秒停顿当休息
        for ph in ["休息"]:
            parts.append(trim_silence(cache[(spk, ph)]))
        parts.append(np.zeros(SR, dtype=np.float32))
        for ph in ["休息结束", "接下来"]:
            parts.append(trim_silence(cache[(spk, ph)]))
        sf.write(OUT / f"E-连听-{spk}.wav", concat(parts, gap_ms=0), SR)
        print(f"  E-连听-{spk}.wav", flush=True)

    # 转 m4a 便于在手机上播放
    for wav in sorted(OUT.glob("*.wav")):
        m4a = wav.with_suffix(".m4a")
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", "128000", str(wav), str(m4a)],
            check=False,
            capture_output=True,
        )
    print(f"\n输出目录 {OUT}")


if __name__ == "__main__":
    main()
