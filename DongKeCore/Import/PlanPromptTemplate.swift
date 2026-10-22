import Foundation

public enum PlanPromptTemplate {
    public static let text = """
    你在帮我生成一份训练计划。请只输出一个 JSON 对象，不要写解释，也不要省略字段。结构如下：

    ```json
    {
      "title": "8 周增肌 · 第 1 周",
      "days": [
        {
          "day": "周一",
          "exercises": [
            { "name": "深蹲", "sets": 4, "reps": "8-12", "restSec": 90 },
            { "name": "哑铃划船", "sets": 3, "reps": 12, "restSec": 60 }
          ]
        },
        {
          "day": "周三",
          "exercises": [
            { "name": "平板支撑", "sets": 3, "durationSec": 45, "restSec": 60 }
          ]
        }
      ]
    }
    ```

    规则：
    1. 最多 7 天，每天一个 day，day 写中文星期或 Day 1 这类序号都行。
    2. 次数写 reps（可以是 "8-12" 这样的区间），按时长做的动作写 durationSec（秒）。
    3. 组间休息写 restSec（秒）；每侧单独做的动作在 name 里注明「每侧」。
    4. 动作用中文或英文都可以，尽量用常见名称（深蹲、俯卧撑、平板支撑、弓步蹲、臀桥…）。
    """
}
