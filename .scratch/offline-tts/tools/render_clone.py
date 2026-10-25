"""用 1.7B-Base + 设计好的参考音 clone 出全部 496 条音条。

与 render_clips.py（0.6B CustomVoice）的区别：
- CustomVoice 每次生成随机抽音高（同句 6 次跨 185 Hz），不能用
- 这里用 VoiceDesign 造出的参考音固化成 prompt，每句都锚定同一段音频
- 输出前做响度归一化（实测 clone 出来的 RMS 差 2.2 倍，忽大忽小会被听成换人）

用法：
    python render_clone.py <输出目录> [--ref B] [--limit N] [--recheck]
"""

import argparse
import os
import subprocess
import time
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
import torch

HERE = Path(__file__).parent
MODEL_DIR = Path(os.environ.get("DK_TTS_BASE17", "/tmp/qwen-tts-bench/model-base-1.7b"))
REF_DIR = Path("/tmp/qwen-tts-bench/lesson")
SAY_DIR = Path("/Users/tango/Developments/SportsHelper/VoiceClips")

TARGET_SR = 22050
TARGET_RMS = 0.10
MAX_GAIN_DB = 12.0
TRIM_DB = -45.0
MAX_ATTEMPTS = 4


def speech_slice(x: np.ndarray) -> tuple[int, int]:
    idx = np.where(np.abs(x) > 10 ** (TRIM_DB / 20))[0]
    return (idx[0], idx[-1] + 1) if len(idx) else (0, len(x))


def trim(x: np.ndarray) -> np.ndarray:
    a, b = speech_slice(x)
    return x[a:b] if b > a else x


def norm_rms(x: np.ndarray) -> np.ndarray:
    """归一化到统一感知响度。

    阈值必须用相对值（峰值的 6%）而不是 −45 dB 绝对值：绝对阈值会把气声和
    尾音算进 RMS，导致「安静的短句」被判定为响度不足而过度放大，实测同一批
    出来的 RMS 会差 1.7 倍。
    """
    y = trim(x)
    peak = float(np.abs(y).max())
    if peak <= 0:
        return y
    idx = np.where(np.abs(y) > peak * 0.06)[0]
    seg = y[idx[0] : idx[-1] + 1] if len(idx) else y
    rms = float(np.sqrt(np.mean(seg**2)))
    if rms < 1e-6:
        return y
    gain = min(TARGET_RMS / rms, 10 ** (MAX_GAIN_DB / 20))
    z = y * gain
    peak = float(np.abs(z).max())
    if peak > 0.89:
        z *= 0.89 / peak
    return z


def say_speech_dur(cid: str) -> float:
    p = SAY_DIR / f"{cid}.wav"
    if not p.exists():
        return 0.0
    x, sr = sf.read(str(p), dtype="float32")
    if x.ndim > 1:
        x = x[:, 0]
    a, b = speech_slice(x)
    return (b - a) / sr


def expected_limit(cid: str, text: str) -> float:
    base = say_speech_dur(cid)
    return base * 1.6 + 0.4 if base > 0 else max(2.0, len(text) / 3.0 + 1.2)


def inventory_tsv() -> Path:
    repo = Path("/Users/tango/Developments/SportsHelper")
    build = Path(subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'],
                                capture_output=True, text=True).stdout.strip()) / "dk-clip-dump"
    build.mkdir(parents=True, exist_ok=True)
    binary = build / "clip-dump"
    if not binary.exists():
        sources = [str(p) for p in (repo / "DongKeCore").rglob("*.swift")]
        subprocess.run(
            ["swiftc", "-O", "-swift-version", "5", "-Xfrontend", "-disable-sandbox",
             "-o", str(binary), str(repo / "Tools/VoiceClipDump/main.swift"), *sources],
            check=True,
        )
    tsv = build / "inventory.tsv"
    with tsv.open("w") as fh:
        subprocess.run([str(binary)], stdout=fh, check=True)
    return tsv


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("--ref", default="B")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--recheck", action="store_true")
    args = ap.parse_args()

    out = Path(args.out_dir)
    if not out.is_dir():
        out.mkdir(parents=True)

    ref_wav = REF_DIR / f"ref-{args.ref}.wav"
    if not ref_wav.exists():
        raise SystemExit(f"缺参考音 {ref_wav}")
    ref_text = "收紧臀部把髋顶到躯干成一条线，别用腰反弓"

    rows = [ln.split("\t", 1) for ln in
            inventory_tsv().read_text(encoding="utf-8-sig").splitlines()]
    if args.limit:
        rows = rows[: args.limit]

    if args.recheck:
        todo = []
        for cid, text in rows:
            wav = out / f"{cid}.wav"
            if not wav.exists():
                todo.append((cid, text))
                continue
            d = sf.info(str(wav)).frames / TARGET_SR
            if d > expected_limit(cid, text):
                print(f"  超标 {d:5.2f}s / 上限 {expected_limit(cid, text):4.2f}s  {text[:18]}",
                      flush=True)
                todo.append((cid, text))
    else:
        todo = [(c, t) for c, t in rows if not (out / f"{c}.wav").exists()]
    print(f"共 {len(rows)} 条，待处理 {len(todo)} 条（音色 {args.ref}）", flush=True)
    if not todo:
        return

    from qwen_tts import Qwen3TTSModel

    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(
        str(MODEL_DIR), device_map="mps", dtype=torch.bfloat16
    )
    prompt = model.create_voice_clone_prompt(
        ref_audio=str(ref_wav), ref_text=ref_text, x_vector_only_mode=False
    )
    print(f"模型加载+prompt {time.perf_counter() - t0:.1f}s，开始渲染", flush=True)

    started = time.perf_counter()
    audio_total = 0.0
    retried = 0
    still_bad: list[tuple[str, float, float, str]] = []

    for i, (cid, text) in enumerate(todo, 1):
        limit = expected_limit(cid, text)
        best: np.ndarray | None = None
        best_s = float("inf")
        attempts = 0
        while attempts < MAX_ATTEMPTS:
            attempts += 1
            wavs, sr = model.generate_voice_clone(
                text=text, language="Chinese", voice_clone_prompt=prompt
            )
            x = trim(np.asarray(wavs[0], dtype=np.float32))
            if sr != TARGET_SR:
                x = librosa.resample(x, orig_sr=sr, target_sr=TARGET_SR)
            d = len(x) / TARGET_SR
            if d < best_s:
                best, best_s = x, d
            if d <= limit:
                break
            print(f"    重试 {text[:14]}：{d:.2f}s > 上限 {limit:.2f}s", flush=True)

        assert best is not None
        if attempts > 1:
            retried += 1
        if best_s > limit:
            still_bad.append((cid, best_s, limit, text))

        sf.write(str(out / f"{cid}.wav"), norm_rms(best), TARGET_SR, subtype="PCM_16")
        (out / f"{cid}.txt").write_text(text)
        audio_total += best_s

        if i % 20 == 0 or i == len(todo):
            elapsed = time.perf_counter() - started
            rate = elapsed / i
            print(f"  [{i}/{len(todo)}] {text[:16]:<18} 均 {rate:4.1f}s/条  "
                  f"剩 {rate * (len(todo) - i) / 60:5.1f} 分钟", flush=True)

    total = time.perf_counter() - started
    print(f"\n完成 {len(todo)} 条：音频 {audio_total / 60:.1f} 分钟，"
          f"耗时 {total / 60:.1f} 分钟，重试 {retried} 条", flush=True)
    if still_bad:
        print(f"⚠️ {len(still_bad)} 条重试后仍超时长：", flush=True)
        for cid, d, lim, text in still_bad:
            print(f"  {cid} {d:5.2f}s / {lim:4.2f}s  {text}", flush=True)
    print(f"输出 {out}", flush=True)


if __name__ == "__main__":
    main()
