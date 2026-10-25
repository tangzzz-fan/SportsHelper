"""整节课试听：Design 出音色 → clone 生成每一段音条 → 响度归一化 → 拼成完整一节课。

为什么逐段生成而不是整句生成：运行时 `ClipSpeechRenderer` 就是按音条拼接播放的，
整句生成听着好不代表拼起来好。测试必须走真实路径。

为什么要响度归一化：clone 出来的 RMS 实测差 2.2 倍，忽大忽小会被听成「换了个人」。
"""

import sys
import time
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
import torch

HERE = Path(__file__).parent
DESIGN_DIR = Path("/tmp/qwen-tts-bench/model-design")
BASE_DIR = Path("/tmp/qwen-tts-bench/model-base-1.7b")
OUT = Path("/tmp/qwen-tts-bench/lesson")
SR_OUT = 22050
GAP_MS = 70  # 与 ClipSpeechRenderer 一致
TARGET_RMS = 0.10
MAX_GAIN_DB = 12.0

# 一节课的播报序列：(整句, 之后的静默秒数)
# 静默模拟真实节奏：组与组之间约 2.5 秒（动作时间），休息 4 秒（真实 20–60 秒，测试用短的）
LESSON = [
    ("开始训练，共 9 组，3 个动作", 2.5),
    ("俯卧撑，第 1 组，共 3 组，10 次", 2.5),
    ("休息", 4.0),
    ("接下来，俯卧撑，第 2 组，共 3 组，10 次", 2.5),
    ("休息", 4.0),
    ("接下来，哑铃划船，第 1 组，每侧 12 次", 2.5),
    ("休息", 4.0),
    ("接下来，平板支撑，第 1 组，40 秒", 2.5),
    ("完成 9 组，完成率 100%", 0.0),
]

CANDIDATES = {
    "A": "沉稳男教练",
    "B": "干练女教练",
    "C": "温和长者",
    "D": "清亮女声",
}

SEPARATORS = set("，、： :,\n")


def fnv1a(text: str) -> str:
    h = 0xCBF29CE484222325
    for b in text.encode():
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def load_phrases() -> tuple[set[str], int]:
    import subprocess

    tsv = Path(subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'],
                              capture_output=True, text=True).stdout.strip()) / "dk-clip-dump" / "inventory.tsv"
    phrases = {ln.split("\t", 1)[1] for ln in tsv.read_text(encoding="utf-8-sig").splitlines()}
    return phrases, max(len(p) for p in phrases)


def segments(text: str, phrases: set[str], longest: int) -> list[str]:
    """照抄 VoiceClipBank.segments：最长匹配，跳过分隔符。"""
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
            raise SystemExit(f"切不出来（运行时会回落 TTS）: {text}")
        out.append(found)
        i += len(found)
    return out


def trim(x: np.ndarray) -> np.ndarray:
    idx = np.where(np.abs(x) > 10 ** (-45 / 20))[0]
    return x[idx[0] : idx[-1] + 1] if len(idx) else x


def norm_rms(x: np.ndarray) -> np.ndarray:
    th = np.abs(x).max() * 0.06
    idx = np.where(np.abs(x) > th)[0]
    if len(idx) == 0:
        return x
    rms = float(np.sqrt(np.mean(x[idx[0] : idx[-1] + 1] ** 2)))
    if rms < 1e-6:
        return x
    gain = TARGET_RMS / rms
    gain = min(gain, 10 ** (MAX_GAIN_DB / 20))
    y = x * gain
    peak = np.abs(y).max()
    if peak > 0.89:
        y *= 0.89 / peak
    return y


def main() -> None:
    # 分两阶段：两个 1.7B 同时驻留要 6.8 GB，16 GB 机器会 swap 到几乎跑不动
    stage = sys.argv[1] if len(sys.argv) > 1 else "lesson"
    keys = sys.argv[2:] or list(CANDIDATES)
    if not OUT.is_dir():
        OUT.mkdir(parents=True)
    phrases, longest = load_phrases()

    # 先把整节课拆成音条，按首次出现顺序去重——同一段只生成一次
    order: list[str] = []
    for sentence, _ in LESSON:
        for seg in segments(sentence, phrases, longest):
            if seg not in order:
                order.append(seg)
    print(f"整节课共 {len(order)} 个唯一音条 × {len(keys)} 个音色", flush=True)

    from qwen_tts import Qwen3TTSModel

    if stage == "ref":
        t0 = time.perf_counter()
        design = Qwen3TTSModel.from_pretrained(DESIGN_DIR, device_map="mps", dtype=torch.bfloat16)
        print(f"VoiceDesign 加载 {time.perf_counter() - t0:.1f}s", flush=True)
        ref_text = "收紧臀部把髋顶到躯干成一条线，别用腰反弓"
        for key in keys:
            instruct = (OUT / f"instruct-{key}.txt").read_text().strip()
            t1 = time.perf_counter()
            wavs, sr = design.generate_voice_design(
                text=ref_text, language="Chinese", instruct=instruct
            )
            ref = trim(np.asarray(wavs[0], dtype=np.float32))
            sf.write(str(OUT / f"ref-{key}.wav"), ref, sr)
            print(f"[{key}] {CANDIDATES[key]} 参考音 {len(ref) / sr:.2f}s "
                  f"({time.perf_counter() - t1:.1f}s)", flush=True)
        return

    t0 = time.perf_counter()
    base = Qwen3TTSModel.from_pretrained(BASE_DIR, device_map="mps", dtype=torch.bfloat16)
    print(f"1.7B-Base 加载 {time.perf_counter() - t0:.1f}s", flush=True)

    for key in keys:
        label = CANDIDATES[key]
        ref_path = OUT / f"ref-{key}.wav"
        if not ref_path.exists():
            print(f"[{key}] 缺参考音，跳过（先跑 stage=ref）", flush=True)
            continue
        ref_text = "收紧臀部把髋顶到躯干成一条线，别用腰反弓"

        t1 = time.perf_counter()
        prompt = base.create_voice_clone_prompt(
            ref_audio=str(ref_path), ref_text=ref_text, x_vector_only_mode=False
        )

        cache: dict[str, np.ndarray] = {}
        for seg in order:
            wavs, sr = base.generate_voice_clone(
                text=seg, language="Chinese", voice_clone_prompt=prompt
            )
            x = trim(np.asarray(wavs[0], dtype=np.float32))
            if sr != SR_OUT:
                x = librosa.resample(x, orig_sr=sr, target_sr=SR_OUT)
            cache[seg] = norm_rms(x)
        print(f"[{key}] {label} {len(order)} 段 clone 完成 "
              f"({time.perf_counter() - t1:.0f}s)", flush=True)

        pieces: list[np.ndarray] = []
        gap = np.zeros(int(SR_OUT * GAP_MS / 1000), dtype=np.float32)
        for sentence, pause in LESSON:
            segs = segments(sentence, phrases, longest)
            for i, seg in enumerate(segs):
                if i:
                    pieces.append(gap)
                pieces.append(cache[seg])
            if pause > 0:
                pieces.append(np.zeros(int(SR_OUT * pause), dtype=np.float32))
        whole = np.concatenate(pieces)
        out_path = OUT / f"lesson-{key}-{label}.wav"
        sf.write(str(out_path), whole, SR_OUT, subtype="PCM_16")

        mf = np.array([librosa.feature.mfcc(y=cache[s], sr=SR_OUT, n_mfcc=20,
                                           hop_length=256).mean(axis=1) for s in order])
        mfn = mf / np.linalg.norm(mf, axis=1, keepdims=True)
        sim = mfn @ mfn.T
        off = [sim[i, j] for i in range(len(order)) for j in range(i + 1, len(order))]
        f0s = []
        for s in order:
            v, _, _ = librosa.pyin(cache[s], fmin=60, fmax=500, sr=SR_OUT,
                                   frame_length=1024, hop_length=256)
            v = v[~np.isnan(v)]
            if len(v):
                f0s.append(float(np.median(v)))
        print(f"     {out_path.name}  {len(whole) / SR_OUT:.1f}s  "
              f"MFCC {np.mean(off):.3f}/{np.min(off):.3f}  "
              f"F0 {min(f0s):.0f}–{max(f0s):.0f} Hz", flush=True)

    print(f"\n输出 {OUT}")


if __name__ == "__main__":
    main()
