"""量音色一致性：同一 speaker 的 496 条音条，基频和音色亮度是否有跳变。

TTS 的典型毛病是「每句都换一个人」——单条听不出来，拼起来就露馅。
客观指标取基频中位数（音高）与频谱质心（音色亮度），两者一起偏才是真跳变。
"""

import sys
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

SR = 22050


def measure(path: Path) -> dict:
    x, sr = sf.read(str(path), dtype="float32")
    if x.ndim > 1:
        x = x[:, 0]
    f0, voiced, _ = librosa.pyin(
        x, fmin=60, fmax=500, sr=sr, frame_length=1024, hop_length=256
    )
    f0v = f0[~np.isnan(f0)]
    cent = librosa.feature.spectral_centroid(y=x, sr=sr, hop_length=256)[0]
    rms = librosa.feature.rms(y=x, hop_length=256)[0]
    loud = rms[rms > rms.max() * 0.1]
    return {
        "dur": len(x) / sr,
        "f0_med": float(np.median(f0v)) if len(f0v) else 0.0,
        "f0_p10": float(np.percentile(f0v, 10)) if len(f0v) else 0.0,
        "f0_p90": float(np.percentile(f0v, 90)) if len(f0v) else 0.0,
        "f0_iqr": float(np.percentile(f0v, 75) - np.percentile(f0v, 25)) if len(f0v) else 0.0,
        "cent_med": float(np.median(cent)),
        "rms_med": float(np.median(loud)) if len(loud) else 0.0,
    }


def main() -> None:
    files = sorted(Path(sys.argv[1]).glob("*.wav"))
    rows = []
    print(f"{'文件':<26}{'时长':>7}{'F0中位':>8}{'F0 IQR':>8}{'质心':>8}{'RMS':>8}")
    for p in files:
        m = measure(p)
        rows.append((p.name, m))
        print(
            f"{p.stem[:24]:<26}{m['dur']:7.2f}{m['f0_med']:8.1f}"
            f"{m['f0_iqr']:8.1f}{m['cent_med']:8.0f}{m['rms_med']:8.3f}"
        )

    f0s = [m["f0_med"] for _, m in rows if m["f0_med"] > 0]
    cents = [m["cent_med"] for _, m in rows if m["f0_med"] > 0]
    if len(f0s) > 1:
        print(f"\nF0 中位 范围 {min(f0s):.1f}–{max(f0s):.1f} Hz，"
              f"跨度 {(max(f0s) - min(f0s)) / np.median(f0s) * 100:.1f}%，标准差 {np.std(f0s):.1f} Hz")
        print(f"质心   范围 {min(cents):.0f}–{max(cents):.0f} Hz，"
              f"跨度 {(max(cents) - min(cents)) / np.median(cents) * 100:.1f}%")
        med = np.median(f0s)
        print("\n偏离中位 F0 超过 8% 的:")
        for name, m in rows:
            if m["f0_med"] > 0 and abs(m["f0_med"] - med) / med > 0.08:
                print(f"  {name:<24} {m['f0_med']:6.1f} Hz  ({(m['f0_med'] - med) / med * 100:+.1f}%)")


if __name__ == "__main__":
    main()
