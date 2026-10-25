"""把 Qwen 版与现有 `say` 版逐条对齐，比时长偏差。

门槛（.scratch/coach-voice/README.md）：单句时长偏差 < 15%。
偏差大了会改拼接节奏——音条之间是 70ms 静音，句子本身变长变短都会听出来。
"""

import json
import subprocess
from pathlib import Path

import soundfile as sf

HERE = Path(__file__).parent
REPO = Path("/Users/tango/Developments/SportsHelper")
INVENTORY = Path(
    subprocess.run(["bash", "-lc", 'echo "${TMPDIR:-/tmp}"'], capture_output=True, text=True)
    .stdout.strip()
) / "dk-clip-dump" / "inventory.tsv"


def fnv1a(text: str) -> str:
    h = 0xCBF29CE484222325
    for b in text.encode():
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def dur(path: Path) -> float:
    info = sf.info(str(path))
    return info.frames / info.samplerate


def main() -> None:
    by_id = {}
    for line in INVENTORY.read_text(encoding="utf-8-sig").splitlines():
        cid, text = line.split("\t", 1)
        by_id[text] = cid

    bench = json.loads((HERE / "bench-mps-Serena.json").read_text())
    rows = []
    for r in bench["rows"]:
        cid = fnv1a(r["text"])
        assert by_id.get(r["text"]) == cid, f"id 不一致: {r['text']}"
        say_wav = REPO / "VoiceClips" / f"{cid}.wav"
        qwen_wav = HERE / "out" / f"mps-{str(r['idx']).zfill(2)}-Serena.wav"
        if not say_wav.exists():
            print(f"缺 say 音条: {r['text']}")
            continue
        s, q = dur(say_wav), dur(qwen_wav)
        rows.append(
            {
                "idx": r["idx"],
                "text": r["text"],
                "say_s": round(s, 3),
                "qwen_s": round(q, 3),
                "delta_pct": round((q - s) / s * 100, 1),
            }
        )

    print(f"{'#':>3} {'say':>6} {'qwen':>6} {'偏差':>7}  文本")
    for row in rows:
        flag = "  ⚠️" if abs(row["delta_pct"]) > 15 else ""
        print(
            f"{row['idx']:>3} {row['say_s']:>6.2f} {row['qwen_s']:>6.2f} "
            f"{row['delta_pct']:>6.1f}%  {row['text'][:22]}{flag}"
        )

    over = [r for r in rows if abs(r["delta_pct"]) > 15]
    mean_abs = sum(abs(r["delta_pct"]) for r in rows) / len(rows)
    print(f"\n超过 15% 的: {len(over)}/{len(rows)}")
    print(f"绝对偏差均值: {mean_abs:.1f}%")
    (HERE / "duration-compare.json").write_text(
        json.dumps({"rows": rows, "over15": len(over), "mean_abs": round(mean_abs, 2)},
                   ensure_ascii=False, indent=2)
    )


if __name__ == "__main__":
    main()
