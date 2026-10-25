"""用 VoiceDesign 生成候选教练音色，再用 Base clone 验证一致性。

为什么要两步：VoiceDesign 能用文字描述出想要的音色，但每条独立生成，音高会漂
（0.6B CustomVoice 实测同句 6 次跨 185 Hz）。官方推荐的做法是
「Design 出一段参考音 → clone 时拿它锚定 → 批量生成」，这样跨 496 条才一致。

用法：
    python design_voice.py design      # 先设计，产出 candidates/
    python design_voice.py clone A     # 用候选 A 的参考音做 clone 一致性验证
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
BASE_DIR = Path("/tmp/qwen-tts-bench/model-base")
OUT = Path("/tmp/qwen-tts-bench/voice")

# 官方示例的 instruct 是结构化的英文：性别、年龄、音域、发声状态、角色
# （见 README「Voice Design then Clone」里的 Male, 17 years old, tenor range...）
CANDIDATES = {
    "A": (
        "沉稳男教练",
        "Male, 32 years old, warm baritone range, calm and steady delivery with quiet "
        "confidence. Professional and encouraging without being overly enthusiastic, "
        "like a personal trainer counting reps beside you.",
    ),
    "B": (
        "干练女教练",
        "Female, 28 years old, clear alto range, brisk and grounded delivery. Direct and "
        "energetic, like a fitness coach calling out a set in a small group class.",
    ),
    "C": (
        "温和长者",
        "Male, 42 years old, low and mellow voice, patient and unhurried delivery. "
        "Experienced and reassuring, like a veteran coach explaining a movement.",
    ),
    "D": (
        "清亮女声",
        "Female, 25 years old, bright and elastic voice with clear rhythm, lively and "
        "upbeat, like an instructor leading a group class.",
    ),
}

# 两段探针：一句报组数（判断数字念法），一句讲要点（判断教练语气）
PROBES = {
    "1-报组": "俯卧撑，第 1 组，共 3 组，10 次",
    "2-要点": "收紧臀部把髋顶到躯干成一条线，别用腰反弓",
}


def speech_stats(x: np.ndarray, sr: int):
    v, _, _ = librosa.pyin(x, fmin=60, fmax=500, sr=sr, frame_length=1024, hop_length=256)
    y = v[~np.isnan(v)]
    c = librosa.feature.spectral_centroid(y=x, sr=sr, hop_length=256)[0]
    rms = librosa.feature.rms(y=x, hop_length=256)[0]
    loud = rms[rms > rms.max() * 0.1] if rms.max() > 0 else rms
    return (
        float(np.median(y)) if len(y) else 0.0,
        float(np.median(c)),
        float(np.median(loud)) if len(loud) else 0.0,
    )


def trim(x: np.ndarray) -> np.ndarray:
    idx = np.where(np.abs(x) > 10 ** (-45 / 20))[0]
    return x[idx[0] : idx[-1] + 1] if len(idx) else x


def do_design() -> None:
    from qwen_tts import Qwen3TTSModel

    if not OUT.is_dir():
        OUT.mkdir(parents=True)
    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(
        str(DESIGN_DIR), device_map="mps", dtype=torch.bfloat16
    )
    print(f"VoiceDesign 加载 {time.perf_counter() - t0:.1f}s", flush=True)

    for key, (label, instruct) in CANDIDATES.items():
        for probe, text in PROBES.items():
            t1 = time.perf_counter()
            wavs, sr = model.generate_voice_design(
                text=text, language="Chinese", instruct=instruct
            )
            x = trim(np.asarray(wavs[0], dtype=np.float32))
            path = OUT / f"{key}-{label}-{probe}.wav"
            sf.write(str(path), x, sr)
            f0, cent, rms = speech_stats(x, sr)
            print(
                f"  {key} {label} {probe}  {len(x) / sr:5.2f}s  "
                f"F0 {f0:6.1f}  质心 {cent:5.0f}  RMS {rms:.3f}  "
                f"({time.perf_counter() - t1:5.1f}s)",
                flush=True,
            )


def do_clone(key: str) -> None:
    """用候选 A 的参考音做 clone，验证跨文本的音高一致性。"""
    from qwen_tts import Qwen3TTSModel

    ref_path = OUT / f"{key}-{CANDIDATES[key][0]}-2-要点.wav"
    if not ref_path.exists():
        raise SystemExit(f"缺参考音 {ref_path}")
    ref_text = PROBES["2-要点"]

    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(
        str(BASE_DIR), device_map="mps", dtype=torch.bfloat16
    )
    print(f"Base 加载 {time.perf_counter() - t0:.1f}s", flush=True)

    prompt = model.create_voice_clone_prompt(
        ref_audio=str(ref_path), ref_text=ref_text, x_vector_only_mode=False
    )
    print("prompt 建好", flush=True)

    # 跨文本一致性：8 条不同文本，看 F0 是否收敛
    probes = [
        "俯卧撑", "休息", "哑铃划船", "平板支撑",
        "开始训练", "完成率 100%", "接下来", "深蹲",
    ]
    f0s = []
    for text in probes:
        wavs, sr = model.generate_voice_clone(
            text=text, language="Chinese", voice_clone_prompt=prompt
        )
        x = trim(np.asarray(wavs[0], dtype=np.float32))
        f0, cent, rms = speech_stats(x, sr)
        f0s.append(f0)
        sf.write(str(OUT / f"clone-{key}-{text.replace(' ', '_')}.wav"), x, sr)
        print(f"  {text:<10} {len(x) / sr:5.2f}s  F0 {f0:6.1f}  RMS {rms:.3f}", flush=True)

    f0s = [f for f in f0s if f > 0]
    print(
        f"\nclone 后 F0 范围 {min(f0s):.0f}–{max(f0s):.0f} Hz，"
        f"跨度 {(max(f0s) - min(f0s)) / np.median(f0s) * 100:.0f}%，"
        f"标准差 {np.std(f0s):.1f} Hz"
    )


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "design"
    if cmd == "design":
        do_design()
    elif cmd == "clone":
        do_clone(sys.argv[2] if len(sys.argv) > 2 else "A")
    else:
        raise SystemExit(f"未知命令 {cmd}")
