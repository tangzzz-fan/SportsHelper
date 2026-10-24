#!/usr/bin/env bash
# 用真实 DeepSeek 接口跑一遍生成链路（编译 DongKeCore + Tools/AISmoke，不依赖 App/模拟器）
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "缺少 .env：先 cp .env.example .env 并填入 DEEPSEEK_API_KEY" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY 为空}"
: "${DEEPSEEK_BASE_URL:=https://api.deepseek.com/v1}"
: "${DEEPSEEK_MODEL:=deepseek-flash}"
export DEEPSEEK_API_KEY DEEPSEEK_BASE_URL DEEPSEEK_MODEL

build_dir="${TMPDIR:-/tmp}/dk-ai-smoke"
mkdir -p "$build_dir"

if [[ ! -x "$build_dir/ai-smoke" || -n "${DK_AI_SMOKE_REBUILD:-}" ]]; then
  echo "编译 smoke（DongKeCore + Tools/AISmoke）…"
  # shellcheck disable=SC2046
  swiftc -O -swift-version 5 \
    -o "$build_dir/ai-smoke" \
    Tools/AISmoke/main.swift \
    $(find DongKeCore -name '*.swift' -print)
fi

exec "$build_dir/ai-smoke" "$@"
