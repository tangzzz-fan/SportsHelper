# 动作图示：规格与新增流程

**本文是动作图示的唯一维护点。** `ARCHITECTURE.md` §12 的「自绘参数化骨架」是早期方案，已作废（见 §4）。

## 1 现在的图示到底是什么

| 问题 | 答案 |
|---|---|
| 是 GIF 吗 | **不是**。项目里没有任何 GIF / PNG / webp 动作图 |
| 是什么 | 矢量 path 字符串，编译进 `DongKeCore/Figure/GeneratedFigureData.swift`（3MB） |
| 怎么动 | 每个动作 **3 个静止姿势**（上游 `frame-1/2/3.svg`）。`Timer.publish(every: 0.8)` 切 index，0.12s easeInOut 淡入淡出 |
| SVG 里有动画吗 | **没有**。`grep animate` 在源 SVG 里为 0 |
| 能不能用 SVG 自带动画 | 能（SMIL `<animate>` 或 CSS），但当前架构不适用：生成器把 SVG 拆成 path DSL，SVG 的动画信息在这一步就丢了。要用得换成保留完整 SVG + WKWebView，为 3 帧切换这点收益不值得 |

## 2 素材的硬规格（可测量，新增时照此对齐）

| 项 | 值 |
|---|---|
| 来源 | [bryllim/workout-guide](https://github.com/bryllim/workout-guide)，源自 Everkinetic，**CC BY-SA 4.0**（必须保留署名） |
| 画布 | 512 × 512，y 向下 |
| 每个动作 | 3 帧 `frame-1/2/3.svg` |
| 着色 | 单色。path 自身是**闭合轮廓**，运行期走 `fill` + `evenodd` 出线条 |
| 线宽 | 由轮廓自身厚度决定；渲染时 `ExerciseFigureView` 按显示尺寸换算 |
| 视角 | `side`（多数）、`front`（开合跳、高抬腿）、`sideLow`（侧平板） |
| 动效标记 | 静态保持 → `motion: .hold`（只显示第一帧）；动态 → `.loop`（可点击播放） |
| 血缘 | 906 帧里 **76 帧（74 个动作）直接改编自 Everkinetic**，manifest 有逐帧 source url；其余 228 个动作是 Bryl Lim 按同风格补画的原创 |

### 2.1 实测基线（同风格生成的验收卡）

对**已上线的 31 个动作、93 帧**逐帧量出来的（512 画布，取 alpha>128 为墨）：

| 指标 | p10 | 中位 | p90 | 极值 |
|---|---|---|---|---|
| 线宽 / 图高 | 0.67% | **1.23%** | 2.90% | 0.41%（高抬腿）– 6.78%（俯卧撑，近景构图） |
| 墨量（墨像素 / 画布 512²） | 3.0% | **5.4%** | 8.1% | 1.5% – 11.8% |
| 图宽 / 图高 | — | **0.87** | — | — |
| 四周留白（最小边 / 512） | 1.2% | **4.5%** | 9.4% | — |

新画的图只有落进这三条才算同风格：**线宽/图高 0.7%–2.9%、墨量 3%–8%、宽高比 0.85 上下**。线宽在 512 画布上约等于 **6px**。

> 别拿 Everkinetic 原始 raster 当基准：它的线宽/图高只有 0.72%，墨量却有 7.7%——**线更细、解剖细节更多**。bryllim 在转矢量时做了「加粗 + 去细节」，正是为了 190pt 下还看得清。原始图直接上 190pt 会糊成噪点。

**注意填色方式**：素材是 `fill + evenodd`。这意味着两条 path 重叠时重叠区会被**挖空**。自绘若也想走素材这条路，必须让所有轮廓互不相交；否则改用 `stroked` 模式（见 §4）。

## 3 新增一个动作的图示（标准流程）

```bash
# 1. 在 302 个上游目录里搜 slug —— 必须靠名字核对，不能猜
ls .scratch/figure-and-glass/assets/workout-guide-main/packages/workout-guide/assets | grep -i 关键词

# 2. 写进 MAPPING
#    .scratch/figure-and-glass/tools/gen_figures.py
#    'your_catalog_id': 'upstream-slug',

# 3. 重新生成
python3 .scratch/figure-and-glass/tools/gen_figures.py

# 4. 看图，不要只看测试绿
python3 - <<'PY'
# 用 Tools/FigureDraw/preview.py 同款渲染方式，或直接跑 App 的 DK_PREVIEW
PY
```

**四条必须校验的**：

1. **姿势是否真的一致**。踩过两次：`march_in_place → walking` 画的是跑步机；`hamstring_stretch` 素材是站姿脚放高处、文字写的坐姿。
2. **静态还是动态**。拉伸与等长保持写进 `STATIC_HOLDS`，否则 3 帧循环播放会让画面在起始位和到位之间反复跳。
3. **文字服从图示**。素材是专业动作库，cues 是自己写的。冲突时改文字，不改图。
4. **别名要同步**。图示按 `catalogId` 取，别漏了 `ExerciseAliasResolver` 的别名，否则新动作导入时认不出来、图也用不上。

## 4 自绘：结论是不可行（已用三代实现验证）

`Tools/FigureDraw/` 是一套参数化人体线稿生成器（`draw_lib.py` 几何库 + `poses.py` 坐标 + `preview.py` 本地预览）。它**当前不产出任何数据**，保留是为了避免下次重走一遍。

三代实现的实际效果：

| 代 | 做法 | 结果 |
|---|---|---|
| 1 | 单线骨架 | 火柴人，比例呆板 |
| 2 | 分节胶囊（每段肢体一条管） | 关节处变成"香肠串" |
| 3 | 连续管状轮廓（斜接补偿）+ 蛋形头 | 木偶感，侧面视角仍会崩 |

**按 App 实际显示尺寸（190pt）与素材并排，差距是质的**：素材有解剖结构、面部朝向、手指、布料褶皱、姿态张力；参数化几何只能给出骨架与轮廓。

所以判据是：**没有素材就不给图，不用简化线稿顶替**。占位图以 0.16 透明度淡显，不会被误读成动作姿势。

### 补图方向（2026-10-24 更正）

**旧结论「Everkinetic 的完整库比 bryllim 的子集大」是错的**，已用根目录的 `everkinetic-data/` 证伪：那是 277 个动作的 raster 原始库，bryllim 是它的**下游**（302 个动作、906 帧矢量）。上游不覆盖下游。

同一个假设导致了 8 个动作缺图，实测下来这条库**一个也补不上**。详见 §6。

### 如果将来一定要自绘

- 必须用 `stroked` 模式（`ExerciseFigure.stroked = true`），否则 `fill + evenodd` 会把重叠的肢体挖空
- 风格参数：512 画布、线宽按显示尺寸 ×0.0084、正面/仰卧姿势尚可、**侧面站姿与跪姿不要尝试**
- 至少要过这一关：190pt 下和素材并排截图，自己看不出违和才算过

## 5 当前覆盖

动作库 39 个 → **31 个有专属图**，8 个走占位：

`hip_circle` / `scapular_circle` / `ankle_circle` / `neck_stretch` / `thread_needle` / `back_stretch` / `dumbbell_floor_press` / `march_in_place`

清单与各自的缺失原因见 `docs/specs/BACKLOG.md` §4。

## 6 Everkinetic 原始库（根目录 `everkinetic-data/`）

2026-10-24 加入。结论先给：**它能用的地方不是「补图」，是「校准尺子」和「文案底本」——8 个缺图没有一个能直接用。**

### 6.1 它到底是什么

| 项 | 事实 |
|---|---|
| 来源 | 第三方收集的 raster 库。原站 `db.everkinetic.com` 已下线，这份是从站点抓下来的副本 |
| 体积 | 277 条记录 / 259 个不重复标题（16 组重名，如 `Squats` 出现 4 次）/ 27 MB |
| 图 | 561 张被引用（目录里 565 个文件，4 个孤儿），**每个动作 2 张**（起始位 / 结束位），不是动画：267 张 GIF 实测 `n_frames = 1` |
| 分辨率 | PNG 268 张，中位 **768 × 900**（最大 1024）；GIF 293 张，中位 **221 × 250**，调色板量化 |
| 配色 | 纯黑描边 + **不透明白底**（不是透明底，不能直接上深色界面） |
| 文本 | 258 条有 `content`（HTML，内嵌 `<h3>Steps</h3>` / `<h3>Tips</h3>`）；19 条是 `steps` 数组 + `tips`；19 条只有 `description` |
| 分类 | `main-muscle` / `secondary-muscle` / `equipment`，英文自由文本，取值不规范（`dumbbell` 与 `dumbbells`、`body only` 与 `body` 并存） |
| 许可证 | ⚠️ 仓库自带的是 **GPL-3.0** LICENSE；上游 [everkinetic/data](https://github.com/everkinetic/data) 声明的才是 **CC BY-SA 4.0** |

### 6.2 和现在这套素材的关系

**bryllim 是它的下游，不是它的子集。** bryllim 的 manifest 里，906 帧中有 76 帧标了 Everkinetic 的 source url（`dist/svg/0042-tension.svg` 这种），另外 228 个动作是 Bryl Lim 按同风格补画的。

所以两者不是「大库 / 小库」的关系，是「raster 母本 / 加粗去细节后的矢量版」。

### 6.3 八个缺图逐条核对

| catalogId | everkinetic 里的候选 | 判定 |
|---|---|---|
| `ankle_circle` | `Ankle Circles` | ❌ 同名但只有 **153 × 175**，190pt 下要放大 2.7 倍 |
| `hip_circle` | 无（`Knee Circles` 是膝踝绕环） | ❌ |
| `scapular_circle` | 无 | ❌ |
| `neck_stretch` | `Static Neck Side Flexion` / `Static Neck Flexion and Extension`（本地这份把它改名成 `Side Neck Isometric` / `Front and Back Neck Isometric`） | ⚠️ 语义对得上——就是静态颈侧屈，上游还带矢量。但两张都是**胸像特写、头顶被裁**，190pt 下与现有全身体例差一个取景档位，**不接入**。实测见 §6.6 |
| `thread_needle` | 无 | ❌ |
| `back_stretch` | 无（`Bridge` 是臀桥、`Back Extension` 是伸背力量） | ❌ |
| `dumbbell_floor_press` | `One Arm Floor Press` | ❌ 器械是**杠铃**、单侧，与哑铃双手地板卧推不符 |
| `march_in_place` | 无 | ❌ |

**8 个都不能直接接。** 最接近的候选要么传达错误姿势，要么取景不同档，和当初「不用近似素材顶替」的判据一致。

### 6.4 那它能用来干什么

1. **风格基线**（§2.1 那张表）。这是它最实的一处价值：把「像不像」变成可测量的区间。
2. **颈部静态屈的现成图**（`0001` / `0002`），服务 `BACKLOG.md` §1 的颈痛方案。语义对得上，卡在取景（§6.6）；若将来给特写单独定一种版式，这两张可以直接用。
3. **文案底本**。258 条带 Steps/Tips 全文。现在 `cues` / `mistakes` 是凭经验写的，以后写新动作可以拿它当参照核对。
4. **矢量源的正主不在本地。** 上游 [everkinetic/data](https://github.com/everkinetic/data) 的 `dist/svg/` 仍在，**CC BY-SA 4.0**，是 277 个动作的 SVG 原稿。格式和 bryllim 同构，能直接接进现有生成器——细节与踩到的坑见 §6.6。

### 6.5 两条不要做

**不要把它打包进 App。** 27 MB、英文文案、不透明白底、GPL-3.0 声明——四条都指向「只作离线参考」。若将来确实要用它的图，按 CC BY-SA 4.0 走**重绘 / 重描**，不要把原文件复制进 bundle。

**不要把 `everkinetic-parser` 移植成 Swift 塞进 App。** 它做的事是：分页遍历 `db.everkinetic.com` → 收集动作页 URL → 抓字段 → 写 `exercises-output.json` → 下载图片。是个一次性爬虫 ETL，而站点已经下线。产物就是我们手里的 `data.json`。把它搬进 App，等于把「已经跑完的离线迁移」重新做成运行时网络抓取，换不来任何用户可见的东西。

真要用它，只有一段值得写成 Swift：`struct EverkineticRecord: Decodable`（约 30 行）。而它的调用方只能是**离线生成脚本**，不是 App。

### 6.6 上游矢量能不能直接接：拿 `neck_stretch` 做的实测

结论：**格式能接，构图不能接。** 这条实测把「没素材」和「有素材但用不了」分开了。

**格式这一关是通的。** 上游每个动作两个 SVG（`NNNN-relaxation.svg` / `NNNN-tension.svg`），和 bryllim 完全同构：

```
<svg viewBox="0 0 167 175"><path fill="#FFF" d="M0 0h167v175H0V0m52.9 17.09c…"/>
```

单条 path，开头一个整画布矩形（`M0 0h167v175H0V0`）当外框，后面全是"被挖掉的墨"。**剥掉第一个子路径**，剩下的子路径配合 `evenodd` 就是线稿本身——和 bryllim 的产物一字不差，不用描线、不用栅格化。`svgcmd.ops` + `svgpath.path_d` 原样可跑。

踩到一个真 bug：上游用了 `A` 弧线命令，而且 flag 连写（`a45.72 45.72 0 01-3.63 2`）。原 tokenizer 把 `01` 读成一个数 `1.0`，参数少一位直接 `IndexError`。已在 `.scratch/figure-and-glass/tools/svgcmd.py` 改成标志位感知扫描，并顺手修正 `T` 的参数个数（应为 2，原写 4）。**回归验证**：重跑 `gen_figures.py`，`GeneratedFigureData.swift` 与改动前**逐字节一致**，bryllim 那 93 帧不受影响。

**构图这一关过不去。** 剥出来跑一遍，`0001` / `0002` 都是**胸像特写、头顶被裁**：图高 138 单位、全身图在 512 画布上是 470 单位。App 按包围盒等比适配，特写会被放大到和全身图一样高，于是脑袋比别人的整个上身还大，线也粗一档。

| | 取景 | 图高（源单位） | 190pt 下观感 |
|---|---|---|---|
| 现有 31 张 | 全身 | 433–470 | 基线 |
| EK 0001 / 0002 | 胸像，头顶裁掉 | 138 / 144 | 明显是另一个档位 |

证据图：`.scratch/figure-and-glass/neck-source-compare.png`（190pt 并排）。

**所以判据要加一条**：能不能用，不只看「有没有这个动作」，还要看**取景是否同档**。全身动作图配胸像特写，用户会以为点错了页面。

顺带纠正一处误读：本地那份 raster 把这两张标注成 `Side Neck Isometric` / `Front and Back Neck Isometric`（等长），而上游的原名是 `Static Neck Side Flexion` / `Static Neck Flexion and Extension`（静态屈）。**看本地标题会误判动作性质，以上游 `exercises.json` 的 `title` 为准。**
