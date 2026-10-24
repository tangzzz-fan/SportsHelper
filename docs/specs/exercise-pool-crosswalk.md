# 动作池对照表（GymMane 448 条 × 我们的 39 条）

> 状态：参考资料，不是运行时数据。任何一条都不得直接进 `ExerciseCatalog`。
> 记录日期：2026-10-24
> 上游：`InlitX/GymMane`（GPLv3 + §7(b) 署名条款），动作条目源自 Everkinetic / workout-guide，CC BY-SA 4.0

## 为什么要有这份表

`docs/specs/BACKLOG.md` §2（臀部缺口）和 §6（扩容准入）都需要回答同一个问题：动作库里到底缺什么、能补的在哪。这份表把「看起来有 448 条」拆成「我们能直接用的有多少」。

## 能挪什么，不能挪什么

| 字段 | 能不能用 | 原因 |
|---|---|---|
| 动作名称、主/次肌群、器械、难度 | **能用** | 事实性数据，不受版权保护 |
| 动作与素材 slug 的对应关系 | **能用** | 与我们 `gen_figures.py` 的 MAPPING 同一套命名 |
| `steps` 英文指导语 | **不要照抄** | 表达性内容，CC BY-SA 4.0，照抄会触发 share-alike |
| 图示（`assets/art/*.txt`） | **无增量** | 388 张里 300 张来自我们已有的 bryllim 302；剩 88 张全是器械向 |
| `kMergedExercises`（169 条） | **不可用** | 映射的是它自己的 id，与我们的 id 空间无关；机制已另实现 |
| 部位不适标注（`affectedParts`） | **没有** | 它整个库没有这个维度 |

## 构成

| 项 | 数量 |
|---|---|
| 动作条目 | 448（原文件 449，1 条 `name` 字段残缺） |
| 矢量图 | 388 张，其中 42 张被复用（`dip` 一张对 6 个动作） |
| 部位（primary） | 14 类 |
| 器械 | 10 类：Bodyweight 141 / Dumbbell 68 / Barbell 64 / Machine 55 / Cable 42 / Band 27 / Weighted 17 / Kettlebell 16 / Rings 14 / Other 5 |
| 难度 | Beginner 253 / Intermediate 152 / Advanced 44 |
| 中文 | **0 条** |

## 与我们 39 条的关系

| 分类 | 数量 | 说明 |
|---|---|---|
| 已有且已接图 | 31 | slug 一一对应，见 `gen_figures.py` 的 MAPPING |
| 已有但无图 | 8 | 绕环 3 个 / 颈肩 / 穿针 / 仰卧抱膝 / 地板卧推 / 原地踏步，上游也没有 |
| 未接·居家可用且非高阶 | 207 | 候选池 |
| 未接·其余（杠铃/绳索/器械/高阶） | 202 | 与「一对哑铃 + 弹力带 + 瑜伽垫」的人设不匹配 |

## 可补池分布（207 条）

| 部位 | 条数 | 部位 | 条数 |
|---|---|---|---|
| glutes | 34 | biceps | 13 |
| back | 27 | obliques | 8 |
| quads | 27 | hamstrings | 8 |
| abdomen | 23 | calves | 7 |
| chest | 22 | trapezius | 4 |
| triceps | 16 | forearm | 2 |
| shoulders | 15 | lowerback | 1 |

## 臀部清单（BACKLOG §2 直接可用）

| 动作 | 器械 | 难度 | slug |
|---|---|---|---|
| Dumbbell Hip Thrust | Dumbbell | Beginner | `dumbbell-hip-thrust` |
| Banded Hip Thrust | Band | Beginner | `banded-hip-thrust` |
| Single-Leg Glute Bridge | Bodyweight | Intermediate | `single-leg-glute-bridge` |
| Clamshell | Bodyweight | Beginner | `clamshell` |
| Banded Clamshell | Band | Beginner | `banded-clamshell` |
| Side-Lying Leg Raise | Bodyweight | Beginner | `side-lying-leg-raise` |
| Side Lying Hip Abduction | Bodyweight | Intermediate | `side-lying-hip-abduction` |
| Frog Pump | Bodyweight | Beginner | `frog-pump` |
| Donkey Kick | Bodyweight | Beginner | `donkey-kick` |
| Fire Hydrant | Bodyweight | Beginner | `fire-hydrant` |
| Glute Bridge March | Bodyweight | Intermediate | `glute-bridge-march` |
| Banded Lateral Walk | Band | Beginner | `banded-lateral-walk` |
| Banded Monster Walk | Band | Beginner | `banded-monster-walk` |
| Curtsy Lunge | Bodyweight | Beginner | `curtsy-lunge` |

以上 slug 全部已核对存在于 `.scratch/figure-and-glass/assets/workout-guide-main`，**图不用另找**。

## 核心清单（举例）

`Hollow Body Hold`、`Bicycle Crunch`、`Reverse Crunch`、`Seated Knee Tuck`、`Alternate Heel Touches`、`Dumbbell Side Bend`。这几条都是现有 6 个核心动作（卷腹/平板/侧平板/死虫/鸟狗/俄罗斯转体）没有覆盖的角度。

## 怎么重新生成

```bash
git clone --depth 1 https://github.com/InlitX/GymMane /tmp/GymMane
```

按 `\n  Exercise\(` 切块，取 `id/name/primary/secondary/equipment/difficulty/art` 七个字段；
与 `gen_figures.py` 的 `MAPPING.values()` 比对得出「未接」；再按 `equipment ∈ {Bodyweight, Dumbbell, Band, Kettlebell, Weighted}` 与 `difficulty != Advanced` 过滤。

## 边界

1. 这份表只回答「库里有什么」，不回答「该不该加」。加不加看 `BACKLOG.md` §6 的准入规则。
2. 移植时必须补齐 `affectedParts`、中文要点、常见错误、低阶替代——参照库一个都没有。
3. 任何动作进库之前，先确认它的 `regressionId` 与既有别名记忆不冲突（例如现有的 `("单腿臀桥", "glute_bridge")` 必须改指）。
