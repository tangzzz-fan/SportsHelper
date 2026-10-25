"""用 Qwen3-TTS 把 VoiceClipBank.inventory 渲染成与 VoiceClips/ 同格式的音条。

与 `scripts/render-voice-clips.sh` 的区别：
- 音源是 Apache-2.0 的 Qwen3-TTS（`say` 版只能内部验证，不能上架）
- 输出前**必须裁首尾静音**（实测固定 0.2s 首 + 0.3s 尾），否则每段之间凭空多 0.55s
- 重采样到 22050，与现有音条完全同格式，替换时播放层不用改

用法：
    python render_clips.py <输出目录> [--limit N] [--offset M]
    python render_clips.py /path/out --limit 20          # 只渲染前 20 条试管线
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import soxr
import torch

HERE = Path(__file__).parent
# 权重 2.3 GB，不进仓库。默认指向调研时下载的位置，可用 DK_TTS_MODEL 覆盖。
MODEL_DIR = Path(os.environ.get("DK_TTS_MODEL", "/tmp/qwen-tts-bench/model"))
TARGET_SR = 22050  # 与 scripts/render-voice-clips.sh 的 --data-format=LEI16@22050 一致
SPEAKER = "Serena"
TRIM_DB = -45.0

# 失控判定。实测中位「实长/上限」= 0.33，即正常音频只用掉三分之一，
# 所以上限可以压到 3 倍左右：再松就抓不到 7 倍那种循环。
EXPECTED_CPS = 3.0  # 保守低估语速 = 高估可接受时长
MAX_ATTEMPTS = 4
SAY_DIR = Path("/Users/tango/Developments/SportsHelper/VoiceClips")


def speech_dur(path: Path) -> float:
    """语音段时长（裁掉首尾静音），用于和 say 版公平对比。"""
    if not path.exists():
        return 0.0
    x, sr = sf.read(str(path), dtype="float32")
    if x.ndim > 1:
        x = x[:, 0]
    idx = np.where(np.abs(x) > 10 ** (TRIM_DB / 20))[0]
    return (idx[-1] - idx[0] + 1) / sr if len(idx) else 0.0


def expected_limit(cid: str, text: str) -> float:
    """这句话最长能接受多少秒。超过就当模型跑飞了。

    优先用 say 版同一条的语音段长度做基准（×1.6 + 0.4s）。按字数估太粗：
    「80 米」正常 0.8 秒，按字数会给出 2.5 秒的许可，正好放过 2.4 秒的跑飞。
    """
    base = speech_dur(SAY_DIR / f"{cid}.wav")
    if base > 0:
        return base * 1.6 + 0.4
    return max(2.0, len(text) / EXPECTED_CPS + 1.2)



def inventory_tsv() -> Path:
    """调用项目已有的 VoiceClipDump，拿「id <TAB> 文本」清单（保证与运行时同一来源）。"""
    repo = Path("/Users/tango/Developments/SportsHelper")
    build = Path(subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'],
                                capture_output=True, text=True).stdout.strip()) / "dk-clip-dump"
    build.mkdir(parents=True, exist_ok=True)
    binary = build / "clip-dump"
    if not binary.exists():
        print("编译 VoiceClipDump…", flush=True)
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


def trim(x: np.ndarray) -> np.ndarray:
    th = 10 ** (TRIM_DB / 20)
    idx = np.where(np.abs(x) > th)[0]
    if len(idx) == 0:
        return x
    return x[idx[0] : idx[-1] + 1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--offset", type=int, default=0)
    ap.add_argument("--recheck", action="store_true",
                    help="只重跑已存在但超时长的条目（失控循环）")
    args = ap.parse_args()

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    rows = []
    for line in inventory_tsv().read_text(encoding="utf-8-sig").splitlines():
        cid, text = line.split("\t", 1)
        rows.append((cid, text))
    rows = rows[args.offset :]
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
                print(f"  超标 {d:5.2f}s / 上限 {expected_limit(cid, text):4.2f}s  {text[:20]}",
                      flush=True)
                todo.append((cid, text))
        print(f"共 {len(rows)} 条，需重跑 {len(todo)} 条", flush=True)
    else:
        todo = [(c, t) for c, t in rows if not (out / f"{c}.wav").exists()]
        print(f"共 {len(rows)} 条，待渲染 {len(todo)} 条（已存在则跳过）", flush=True)

    if not todo:
        return

    from qwen_tts import Qwen3TTSModel

    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(
        str(MODEL_DIR), device_map="mps", dtype=torch.bfloat16
    )
    print(f"模型加载 {time.perf_counter() - t0:.1f}s，开始渲染", flush=True)

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
            wavs, sr = model.generate_custom_voice(
                text=text, speaker=SPEAKER, language="Chinese"
            )
            x = np.asarray(wavs[0], dtype=np.float32)
            if x.ndim > 1:
                x = x[:, 0]
            x = trim(x)
            if sr != TARGET_SR:
                x = soxr.resample(x, sr, TARGET_SR)
            d = len(x) / TARGET_SR
            if d < best_s:
                best, best_s = x, d
            if d <= limit:
                break
            print(f"    重试 {text[:16]}：{d:.2f}s > 上限 {limit:.2f}s", flush=True)

        assert best is not None
        if attempts > 1:
            retried += 1
        if best_s > limit:
            still_bad.append((cid, best_s, limit, text))

        sf.write(str(out / f"{cid}.wav"), best, TARGET_SR, subtype="PCM_16")
        (out / f"{cid}.txt").write_text(text)
        audio_total += best_s

        elapsed = time.perf_counter() - started
        if i % 10 == 0 or i == len(todo):
            rate = elapsed / i
            eta = rate * (len(todo) - i)
            print(
                f"  [{i}/{len(todo)}] {text[:18]:<20} "
                f"均 {rate:4.1f}s/条  剩 {eta / 60:5.1f} 分钟",
                flush=True,
            )

    total = time.perf_counter() - started
    print(
        f"\n完成 {len(todo)} 条：音频 {audio_total / 60:.1f} 分钟，"
        f"耗时 {total / 60:.1f} 分钟，RTF {total / audio_total:.2f}，"
        f"重试过 {retried} 条",
        flush=True,
    )
    if still_bad:
        print(f"⚠️ {len(still_bad)} 条重试 {MAX_ATTEMPTS} 次仍超时长：", flush=True)
        for cid, d, lim, text in still_bad:
            print(f"  {cid} {d:5.2f}s / {lim:4.2f}s  {text}", flush=True)
    print(f"输出 {out}", flush=True)


if __name__ == "__main__":
    main()
