#!/usr/bin/env bash
# 判定这次改动需要跑哪一档测试：none / core / ui
#
#   scripts/test-scope.sh                  # 只看判定，打印依据
#   scripts/test-scope.sh --run            # 判定后直接跑对应档位
#   scripts/test-scope.sh --run --base HEAD~1
#
# 判据只有一条：**改动会不会让「用户点得到的东西」变样**。
#   Core 纯逻辑（DongKeCore）→ 单测覆盖得住，不必起模拟器
#   视图 / 入口 / 设计系统 / 持久化 / 工程配置 → 必须跑 UI
#   纯文档 → 一档都不跑（仍要过 §4.3 门禁）
set -uo pipefail

cd "$(dirname "$0")/.."

BASE=""
RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --run)  RUN=1; shift ;;
    --base) BASE="$2"; shift 2 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

if [ -z "$BASE" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE="origin/main"
  else
    BASE="HEAD"
  fi
fi

FILES=$(
  {
    git diff --name-only "$BASE"...HEAD 2>/dev/null
    git diff --name-only 2>/dev/null
    git diff --cached --name-only 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
)

if [ -z "$FILES" ]; then
  echo "scope: none"
  echo "reason: 与 $BASE 相比没有改动"
  exit 0
fi

UI_PATTERNS='^(DongKe/|Shared/|DongKeUITests/|project\.yml$|DongKe\.xcodeproj/)'
CORE_PATTERNS='^(DongKeCore/|DongKeCoreTests/|Tools/)'
DOC_PATTERNS='^(docs/|\.scratch/|[^/]+\.md$|\.env\.example$)'

UI_HITS=$(printf '%s\n' "$FILES" | grep -E "$UI_PATTERNS")
CORE_HITS=$(printf '%s\n' "$FILES" | grep -E "$CORE_PATTERNS")
OTHER_HITS=$(printf '%s\n' "$FILES" | grep -Ev "$UI_PATTERNS|$CORE_PATTERNS|$DOC_PATTERNS")

SCOPE="none"
REASON="只动了文档"

if [ -n "$UI_HITS" ]; then
  SCOPE="ui"
  REASON="动了 App / 视图 / 工程配置，用户点得到的东西可能变样"
elif [ -n "$CORE_HITS" ]; then
  SCOPE="core"
  REASON="只动了 DongKeCore，行为由单测覆盖"
elif [ -n "$OTHER_HITS" ]; then
  SCOPE="core"
  REASON="动了脚本或配置，先按 Core 档验证"
fi

echo "scope: $SCOPE"
echo "reason: $REASON"
echo "base: $BASE"
echo "files:"
printf '%s\n' "$FILES" | sed 's/^/  /'

if [ "$SCOPE" = "ui" ]; then
  echo "ui-triggers:"
  printf '%s\n' "$UI_HITS" | sed 's/^/  /'
fi

if [ "$RUN" = "0" ]; then
  exit 0
fi

sandbox_escape_needed() {
  ! sandbox-exec -p '(version 1)(deny default)(allow file-read*)' /bin/echo ok >/dev/null 2>&1
}

pick_simulator_udid() {
  xcrun simctl list devices available --json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin).get("devices", {})
except Exception:
    sys.exit(1)
for runtime in sorted(data, reverse=True):
    for device in data[runtime]:
        if device.get("isAvailable") and "iPhone" in device.get("name", ""):
            print(device["udid"])
            sys.exit(0)
sys.exit(1)
'
}

run_tests() {
  local only="$1"
  local udid
  udid=$(pick_simulator_udid)
  if [ -z "$udid" ]; then
    echo "找不到可用模拟器" >&2
    return 1
  fi

  local args=(
    -project DongKe.xcodeproj
    -scheme DongKe
    -destination "id=$udid"
    -derivedDataPath DerivedData
    -only-testing:"$only"
    test
  )
  if sandbox_escape_needed; then
    args=(OTHER_SWIFT_FLAGS=-disable-sandbox "${args[@]}")
  fi

  local log="/tmp/test-scope-${only//\//-}-$(date +%H%M%S).log"
  echo "  xcodebuild -only-testing:$only  → $log"
  perl -e 'alarm shift; exec @ARGV' 2400 xcodebuild "${args[@]}" > "$log" 2>&1
  local code=$?

  if grep -qE "\*\* TEST FAILED \*\*|Executed [0-9]+ tests?, with [1-9][0-9]* failure|✘ Test run" "$log"; then
    grep -E "error:|Test Case .* failed|Executed [0-9]+ tests?, with [1-9]|✘ Test run" "$log" | tail -15
    return 1
  fi
  if grep -qE "\*\* TEST SUCCEEDED \*\*|Executed [0-9]+ tests?, with 0 failures|✔ Test run with" "$log"; then
    grep -E "✔ Test run with|Executed [0-9]+ tests?, with 0 failures" "$log" | grep -v "Executed 0 tests" | tail -3
    return 0
  fi

  echo "  没拿到明确结论（退出码 $code），末尾 10 行：" >&2
  tail -10 "$log" >&2
  return 1
}

FAILED=0
case "$SCOPE" in
  none)
    echo "→ 跳过测试（仍需过 docs/ARCHITECTURE.md §4.3 门禁）"
    ;;
  core)
    echo "→ 跑单测"
    run_tests DongKeCoreTests || FAILED=1
    ;;
  ui)
    echo "→ 跑单测"
    run_tests DongKeCoreTests || FAILED=1
    echo "→ 跑 UI 测试"
    run_tests DongKeUITests || FAILED=1
    ;;
esac

if [ "$FAILED" = "1" ]; then
  echo "✘ 有档位没过"
  exit 1
fi
echo "✓ 该跑的档位都过了"
