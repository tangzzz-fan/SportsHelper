#!/usr/bin/env bash
# 阶段 0 的原型渲染：把 VoiceClipBank.inventory 逐条用系统 TTS 念成 WAV。
#
# ⚠️ 用 macOS `say` 生成的音频**只能内部验证拼接感，不能随包上架**
#    （Apple 的语音只授权个人使用）。正式音条要用 CosyVoice2 之类的
#    Apache-2.0 模型重渲染，见 .scratch/coach-voice/README.md。
set -euo pipefail

cd "$(dirname "$0")/.."

VOICE="${DK_CLIP_VOICE:-声音2}"
OUT="${DK_CLIP_OUT:-VoiceClips}"
BUILD="${TMPDIR:-/tmp}/dk-clip-dump"

mkdir -p "$BUILD" "$OUT"

if [[ ! -x "$BUILD/clip-dump" || -n "${DK_CLIP_REBUILD:-}" ]]; then
  echo "编译 VoiceClipDump…" >&2
  # shellcheck disable=SC2046
  swiftc -O -swift-version 5 -Xfrontend -disable-sandbox \
    -o "$BUILD/clip-dump" \
    Tools/VoiceClipDump/main.swift \
    $(find DongKeCore -name '*.swift' -print) 2>/dev/null
fi

"$BUILD/clip-dump" > "$BUILD/inventory.tsv"
total=$(wc -l < "$BUILD/inventory.tsv" | tr -d ' ')
echo "共 $total 条，语音 = $VOICE" >&2

done=0
while IFS=$'\t' read -r id text; do
  target="$OUT/$id.wav"
  stable="$OUT/$id.txt"
  if [[ -f "$target" && -f "$stable" && "$(cat "$stable")" == "$text" ]]; then
    continue
  fi
  say -v "$VOICE" -o "$target" --data-format=LEI16@22050 "$text"
  printf '%s' "$text" > "$stable"
  done=$((done + 1))
  if (( done % 25 == 0 )); then echo "  已渲染 $done" >&2; fi
done < "$BUILD/inventory.tsv"

echo "完成：$OUT 里 $(ls "$OUT"/*.wav 2>/dev/null | wc -l | tr -d ' ') 个音条" >&2
