#!/usr/bin/env bash
# 在模拟器 App 内跑真实 AI 生成（需要先 build 出 .app）
# 用法：scripts/ai-sim.sh [模拟器 UDID，默认 booted]
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

UDID="${1:-booted}"
APP="DerivedData/Build/Products/Debug-iphonesimulator/DongKe.app"

if [[ ! -d "$APP" ]]; then
  echo "找不到 $APP，先跑：ios-run.sh build --project DongKe.xcodeproj --scheme DongKe --sim <UDID>" >&2
  exit 1
fi

xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" app.dongke.ios 2>/dev/null || true

SIMCTL_CHILD_DK_COMPLETE_ONBOARDING=1 \
SIMCTL_CHILD_DK_PREVIEW=import \
SIMCTL_CHILD_DK_AI_BASE_URL="$DEEPSEEK_BASE_URL" \
SIMCTL_CHILD_DK_AI_MODEL="$DEEPSEEK_MODEL" \
SIMCTL_CHILD_DK_AI_KEY="$DEEPSEEK_API_KEY" \
SIMCTL_CHILD_DK_AI_AUTOGEN=1 \
xcrun simctl launch "$UDID" app.dongke.ios

echo "已启动；生成约 25–30 秒后应停在「校对」页。截图："
echo "  xcrun simctl io $UDID screenshot /tmp/dk-ai-app.png"
