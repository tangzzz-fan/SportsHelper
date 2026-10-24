#!/usr/bin/env bash
# 把「训练计划 → 播报文案」逐条打出来，用来核对文字和计划是否对得上
set -euo pipefail

cd "$(dirname "$0")/.."

build_dir="${TMPDIR:-/tmp}/dk-voice-dump"
mkdir -p "$build_dir"

if [[ ! -x "$build_dir/voice-dump" || -n "${DK_VOICE_DUMP_REBUILD:-}" ]]; then
  echo "编译 VoiceDump（DongKeCore + Tools/VoiceDump）…" >&2
  # shellcheck disable=SC2046
  swiftc -O -swift-version 5 -Xfrontend -disable-sandbox \
    -o "$build_dir/voice-dump" \
    Tools/VoiceDump/main.swift \
    $(find DongKeCore -name '*.swift' -print) 2>/dev/null
fi

exec "$build_dir/voice-dump" "$@"
