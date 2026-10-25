"""量 Qwen3-TTS 0.6B 在 M2 上的实际合成速度。

只做一件事：逐条合成 samples.tsv，记录「墙钟耗时 / 音频时长」。
不评估音质——音质靠人耳盲听，脚本给不出。
"""

import csv
import json
import sys
import time
from pathlib import Path

import soundfile as sf
import torch

HERE = Path(__file__).parent
MODEL_DIR = HERE / "model"
OUT = HERE / "out"
SPEAKER = sys.argv[1] if len(sys.argv) > 1 else "Serena"
TAG = sys.argv[2] if len(sys.argv) > 2 else "mps"


def pick_device() -> str:
    if torch.backends.mps.is_available():
        return "mps"
    if torch.cuda.is_available():
        return "cuda:0"
    return "cpu"


def main() -> None:
    from qwen_tts import Qwen3TTSModel

    OUT.mkdir(parents=True, exist_ok=True) if not OUT.is_dir() else None
    device = pick_device()
    print(f"device={device} speaker={SPEAKER} torch={torch.__version__}", flush=True)

    t0 = time.perf_counter()
    model = Qwen3TTSModel.from_pretrained(
        str(MODEL_DIR),
        device_map=device,
        dtype=torch.float32 if device == "mps" else torch.bfloat16,
    )
    load_s = time.perf_counter() - t0
    print(f"load={load_s:.1f}s", flush=True)

    rows = []
    for line in (HERE / "samples.tsv").read_text(encoding="utf-8-sig").splitlines():
        idx, text = line.split("\t", 1)
        if idx == "1":  # 首条含冷启动，单独标记但仍计入
            cold = True
        else:
            cold = False
        t0 = time.perf_counter()
        wavs, sr = model.generate_custom_voice(
            text=text, language="Chinese", speaker=SPEAKER
        )
        gen_s = time.perf_counter() - t0
        audio = wavs[0]
        dur = len(audio) / sr
        rtf = gen_s / dur if dur > 0 else float("inf")
        name = f"{TAG}-{idx.zfill(2)}-{SPEAKER}.wav"
        sf.write(OUT / name, audio, sr)
        rows.append(
            {
                "idx": int(idx),
                "text": text,
                "chars": len(text),
                "sr": sr,
                "audio_s": round(dur, 3),
                "gen_s": round(gen_s, 3),
                "rtf": round(rtf, 3),
                "cold": cold,
            }
        )
        print(
            f"[{idx:>2}] {dur:5.2f}s audio  {gen_s:6.2f}s gen  RTF {rtf:5.2f}  {text[:24]}",
            flush=True,
        )

    warm = [r for r in rows if not r["cold"]]
    summary = {
        "device": device,
        "speaker": SPEAKER,
        "load_s": round(load_s, 2),
        "sr": rows[0]["sr"],
        "n": len(rows),
        "total_audio_s": round(sum(r["audio_s"] for r in rows), 2),
        "total_gen_s": round(sum(r["gen_s"] for r in rows), 2),
        "rtf_warm_mean": round(sum(r["rtf"] for r in warm) / len(warm), 3),
        "rtf_warm_p50": sorted(r["rtf"] for r in warm)[len(warm) // 2],
        "rtf_warm_max": max(r["rtf"] for r in warm),
        "rows": rows,
    }
    (HERE / f"bench-{TAG}-{SPEAKER}.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2)
    )
    with (HERE / f"bench-{TAG}-{SPEAKER}.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    print("\n=== summary ===")
    for k in (
        "device",
        "speaker",
        "sr",
        "load_s",
        "total_audio_s",
        "total_gen_s",
        "rtf_warm_mean",
        "rtf_warm_p50",
        "rtf_warm_max",
    ):
        print(f"{k:>16}: {summary[k]}")


if __name__ == "__main__":
    main()
