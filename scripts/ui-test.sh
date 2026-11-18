#!/usr/bin/env bash
# 单独跑那条 UI 测试：重量落库后杀掉重进还在不在。
# 不进默认测试——理由见 docs/HANDOFF.md §6.6：这条链只有它能验，但它慢，
# 所以只在改了 DongKe/Data/Persistence 或 DongKe/Features/Workout 之后手动跑。
#
# 用法：scripts/ui-test.sh [模拟器 UDID]
set -euo pipefail

cd "$(dirname "$0")/.."

UDID="${1:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices booted | grep -m1 -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)"
fi
if [[ -z "$UDID" ]]; then
  echo "没有已启动的模拟器。先 boot 一台，或把 UDID 作为第一个参数。"
  exit 2
fi
echo "模拟器：$UDID"

xcodegen generate >/dev/null

echo "编译…"
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination "id=$UDID" -derivedDataPath /tmp/dk \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' \
  build-for-testing >/tmp/dk-ui-build.log 2>&1 || {
    echo "构建失败，看 /tmp/dk-ui-build.log"
    grep -E "error:" /tmp/dk-ui-build.log | head -10 || true
    exit 1
  }

echo "跑测试…"
python3 - "$UDID" <<'PY'
import subprocess, sys
udid = sys.argv[1]
cmd = ["xcodebuild", "-project", "DongKe.xcodeproj", "-scheme", "DongKe",
       "-destination", f"id={udid}", "-derivedDataPath", "/tmp/dk",
       "-only-testing:DongKeUITests", "test-without-building"]
with open("/tmp/dk-ui-test.log", "w") as f:
    p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
    try:
        p.wait(timeout=240)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
PY

if grep -q "TEST EXECUTE SUCCEEDED" /tmp/dk-ui-test.log; then
  grep -E "Test Case .* (passed|failed)|Executed [0-9]+ test" /tmp/dk-ui-test.log | tail -2
  exit 0
fi

grep -E "✘|failed|error:" /tmp/dk-ui-test.log | tail -20
exit 1
