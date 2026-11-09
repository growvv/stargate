# 鸿蒙功能聚合面板 · iOS 对齐设计定稿（Stage −1）

- 日期：2026-11-07
- 效力：本文件是 `2026-11-07-harmony-atomic-function-panel-product-design.md` 的 **§0.4 定稿补充**，替换产品 Spec 中「UI 视觉 / 推荐机制 / 分类划分 / 拼音分组」的方向性占位值，供 Task 2 / Task 3 / Task 6 消费。
- **不重开**结构形态（4×4 卡片、分类/全量/搜索、长按交给桌面系统菜单）；**不改**产品 Spec §0.4 的三条硬约束（建议区全自动且不允许手动干预；失败不回退 App 首页、运行时不做多路由降级；「换方案」只在工程/预研层）。
- 对齐层级：**范式对齐**（信息组织、建议区形态、材质感、分组索引），**非机制复刻**。客户端私有框架机制级逆向本机不可执行，服务端/ML 侧排序逻辑不在取证范围（§0.8 / C1 主路径）。
- 依据层级：**[S]** 静态取证（可引用的公开文档/WWDC 转录/GitHub 文档结论）；**[I]** 公开资料推断（由可观察行为归纳）。**不把推断冒充静态取证**。
- B3 验收格式：分类 / 推荐 / 视觉三维度（外加拼音维度）每条结论均给出「对齐 iOS 哪一点 + 取证来源 + 鸿蒙卡片形态下的可行性取舍」三栏，并标注依据层级；无像素级截图比对。
- 取证明细：`docs/research/ios-paradigm-reverse.md`。

---

## 0. 四组定稿取值总览（供实现直接引用）

| 组 | 落地位置 | 一句话定稿 |
|---|---|---|
| `IOS_VISUAL_SPEC` | `ThemeTokens.ets` / `WidgetCard.ets` | 半透明材质 + 背景模糊 + 柔和渐变 + 连续圆角近似 + 材质上高对比文字 + 独立暗色配色；模糊不可用时退化半透明纯色 |
| `IOS_RANKING_SPEC` | `RankingEngine.topN` / `UsageSnapshot` | 可解释加权公式（日/月频次、时间衰减、时段、场景、序列、路由置信度）+ 类目打散 + 冷启动时段先验；完全自动、最多 8 格、不凑数 |
| `IOS_CATEGORY_SPEC` | `capabilities.json` / `TestFixtures.ets` / `WidgetCardData` | 系统预置语义类目、离线归属、用户不可增删改类目、可重排类目顺序；全量浏览 A–Z |
| `IOS_PINYIN_SPEC` | `PinyinUtil.ets` / 全量列表 | 离线常用汉字→首字母表，多音字取常用读音，A–Z + `#` 杂项桶，空态不崩溃 |

---

## 1. 分类维度（`IOS_CATEGORY_SPEC`）

| # | 对齐 iOS 哪一点 | 取证来源（框架/符号/公开资料） | 鸿蒙卡片形态下的可行性取舍 | 依据层级 |
|---|---|---|---|---|
| C1 | App Library 用**系统定义的语义类目**自动归类，不是用户自定义分类 | Apple 支持文档《Find and use your apps in App Library》(`support.apple.com/guide/iphone/find-and-use-your-apps-in-app-library-iphb1f67e6b9/ios`，curl HTTP 200)；WebSearch 第三方可观察结论（iOS 14 引入、自动归入 Social/效率/娱乐 等） | 卡片内不做归类算法：能力库 `capabilities.json` 每条**离线预置**单一 `category` 字符串；未知条目归 `其他`。不做运行时 ML 分类 | [S]/[I] |
| C2 | 类目集合与命名由系统预置、本地化，用户不能新增/重命名/删除 | 同上 Apple 支持文档；iOS 15+ 仅可在 App Library 内重排 | 类目集合固定为 **9 个有序中文类目**：`支付`、`购物`、`出行`、`社交`、`生活`、`娱乐`、`健康运动`、`工具效率`、`其他`。配置页**不做分类增删改**；仅保留 `CatalogEditor.reorderCategory(name, ids)` 做类目顺序/类目内条目顺序调整 | [S] |
| C3 | 类目内按名称/系统序排列，全量可按字母浏览 | Apple 支持文档（App Library 搜索与按字母浏览）；HIG「Lists and tables / Index lists」 | 分类页按类目顺序展示；全量页按 `PinyinUtil.group` 得到 A–Z + `#` 分组，不按 bundleName 排序 | [S]/[I] |
| C4 | 高频 App 置顶在顶部「Suggestions」区（少量，约 4 个） | Apple 支持文档 + WWDC20「What's new in iOS」App Library 介绍；WebSearch 可观察结论（Suggestions / Recently Added 文件夹） | 4×4 卡片顶部建议区最多 **8 格**（卡片面积折中，非 iOS 的 4 格）；不足按实际数量显示、不凑数、不填未验证条目（§0.9 B2′） | [S]/[I] |

**定稿取值 — 类目集合（有序）**：

```
支付, 购物, 出行, 社交, 生活, 娱乐, 健康运动, 工具效率, 其他
```

**归属规则**：能力库离线给每条 `AtomicFunction.category`；取值必须 ∈ 上述集合；不在集合内 → `其他`。iOS 的类别判定算法为系统私有（不取证），本产品用**离线人工归属**近似，明确为范式对齐。

**排序方式**：类目按上表顺序；类目内按 `label` 的拼音首字母 + 原串比较；全量页分组键 A–Z + `#`。

---

## 2. 推荐维度（`IOS_RANKING_SPEC`）

| # | 对齐 iOS 哪一点 | 取证来源（框架/符号/公开资料） | 鸿蒙卡片形态下的可行性取舍 | 依据层级 |
|---|---|---|---|---|
| R1 | Siri 建议由**捐赠的动作 + 时间/地点/其他上下文信号**驱动，on-device 学习 | WWDC18 Session 211「Introduction to Siri Shortcuts」转录（`apple-docs.everest.mt/docs/wwdc/wwdc2018-211`，curl HTTP 200）直接引文："the system will look at the **time, location, and other signals** … **the time of day and the day of the week** … a **significant location**"；Apple 开发者文档《Increasing App Usage with Suggestions Based on User Activities》（`NSUserActivity.isEligibleForPrediction` / 捐赠 `INInteraction`） | 无系统捐赠/地点权限，改用**自身用量记录**近似：`dayCount` / `monthCount` / `lastUsedAt` / `hourAffinity` / `sceneAffinity` / `recentSequence`；不引入位置、不引入 ML 依赖 | [S] |
| R2 | 建议随时间与场景变化，展示**少量最相关项**而非全量排序 | WWDC18 211 汤/咖啡时段例子；WWDC20 10087「Design for intelligence」把捐赠表述为 on-device 上下文记录；Apple 支持文档「Suggestions」 | `RankingEngine.topN(items, usage, now, n)` 返回最多 `n=8` 条；`now` 参与时段与衰减，点击即重排（A2）、定时刷新兜底 | [S]/[I] |
| R3 | 冷启动用系统默认/热门建议，随个人使用收敛（Apple 未公开先验公式） | Apple 支持文档 + 公开观察 | 无历史时按**时段先验**（`hourAffinity`）给不同类目不同基数，再随用量收敛；具体权重为本产品自定近似，**不宣称是 iOS 数值** | [I] |
| R4 | 建议区避免同类霸屏（可观察），具体打散算法未公开 | 公开观察 | 打散：在 `topN` 结果里**同一 `category` 最多 2 条**；候选不足时按分数补足，但**不填充未验证条目、不凑满 8 格** | [I] |
| R5 | 用户**不能手工钉住**某个 App 进建议区；建议区完全自动 | Apple 支持文档「Turn off Siri Suggestions」；iOS 设置 > Siri & Search；产品 Spec §0.4 硬约束 | `UsageSnapshot` **不含** `isPinned`，公式**不含** pinnedBoost / 收藏因子；产品 Spec 第二轮 B2 已去掉推荐开关；建议区无手动干预入口 | [S] |
| R6 | 排序权重/ML 模型在服务端或系统私有框架，Apple 未公开，不可静态复刻 | 产品 Spec §0.8 / C1 决议；本机 Ghidra/IDA/Hopper/Kuna 均未配置 | 用**可解释线性加权**近似，权重写死在 `RankingEngine` 常量并标注「范式对齐近似」；不下载 IPSW / 不做私有框架深度反编译 | [I]（明确不在取证范围） |

**定稿取值 — 加权公式**：

```
score(f, now) =
    0.30 * norm(dayCount(f, now))
  + 0.20 * norm(monthCount(f, now))
  + 0.18 * exp(-Δt / τ)                 // Δt = now - lastUsedAt(f)，τ = 36h
  + 0.12 * hourAffinity(f, nowHour)     // 冷启动先验也走这里
  + 0.08 * sceneAffinity(f, scene)
  + 0.07 * seqBoost(f, recentSequence())
  + 0.05 * confidence                   // 来源置信度 L1=1.0 … L5=0.2
```

- `norm(x)` = 相对当前候选项集合的 `x / maxX`（maxX=0 时取 0），避免绝对值尺度漂移。
- `exp(-Δt/τ)`：无历史 `lastUsedAt` 时按 0 处理；`τ = 36 * 3600 * 1000` ms。
- `sceneAffinity`：首版取常量 0（无场景传感器），保留接口。
- `seqBoost`：出现在最近序列中给 1，否则 0。
- `confidence`：取 `AtomicFunction.confidence`，clamp 到 [0,1]。
- **打散**：按分数降序取前 `n`，但任一 `category` 已选满 2 条则跳过；不足 `n` 时**返回实际条数**，绝不补位（B2′）。
- **稳定性**：分数相同按 `id` 字典序，保证同一输入结果可复现。
- **无** `isPinned`、**无** `pinnedBoost`、**无**收藏因子、**无**用户可关闭的推荐开关。

---

## 3. 视觉维度（`IOS_VISUAL_SPEC`）

| # | 对齐 iOS 哪一点 | 取证来源（框架/符号/公开资料） | 鸿蒙卡片形态下的可行性取舍 | 依据层级 |
|---|---|---|---|---|
| V1 | 控制中心/通知/文件夹用**半透明材质 + 背景模糊**，让壁纸透出、强调层次 | Apple HIG「Materials」(`developer.apple.com/design/human-interface-guidelines/materials`)：材质让背景色透出、分离前景文字与控件；clarity / deference / depth；系统材质自动适配 light/dark | ArkTS 卡片用 `backdrop-filter: blur(12–14px)` + `background: #ffffff30`；**Task 0 `BLUR_SUPPORTED` 探针决定**是否可用；卡片渲染进程独立，不能用 `@State`/复杂手势 | [S] |
| V2 | 柔和渐变壁纸感，材质叠加在彩色背景上 | HIG「Materials / Backgrounds / Color」；iOS 壁纸与渐变可观察行为 | 保留方向性渐变 `linear-gradient(150deg,#8e9ff5,#c9a7e8 45%,#f3b6c2)` 作为卡片底层氛围；**数值为鸿蒙侧实现取值，不宣称是 iOS 色值** | [I] |
| V3 | 连续圆角（squircle），圆角随层级递进；HIG 不固定 px | HIG「Materials / Layout」；Apple 设计资源 | ArkUI 仅支持普通 `borderRadius`：卡片 22vp、分类 chip 14–18vp、图标 10–12vp 近似层级递进；不追求像素级 squircle | [S]/[I] |
| V4 | 材质上文字保持**足够对比度**，系统材质随明暗切换前景色 | HIG「Color / Dark Mode / Accessibility - Contrast」 | 浅/深底均用高对比白字：主文字 `#ffffff`、次文字 `#ffffffd9`；边框 `1px solid #ffffff55` | [S] |
| V5 | 暗色模式是**独立设计的配色与材质**，不是简单反相 | HIG「Dark Mode」 | 暗色单独取值：卡片底 `#00000030`、边框 `#ffffff33`、主文字 `#ffffff`；渐变降饱和（`#4a5680`→`#6b5a80`→`#805a66`）。`ThemeTokens.build(blurAvailable, dark)` 双参数 | [S] |
| V6 | 全量列表用 A–Z 分组 + 右侧索引条 | HIG「Lists and tables / Index lists」；iOS 通讯录/Spotlight 可观察行为 | 全量页用 `PinyinUtil.group` 分组 + A–Z/`#` 索引；卡片内**不**放索引条（面积与事件限制） | [S]/[I] |
| V7 | 系统有动效，但卡片内请勿定义复杂交互 | HIG「Motion」；HarmonyOS ArkTS Card 官方设计指南「卡片内请勿定义复杂交互」 | 卡片内**不做动效 / 长按 / 拖拽 / 多指**；仅 `postCardAction` 点击；动效留待非卡片页面且首版不做 | [S] |

**定稿取值 — `ThemeTokens.build(blurAvailable, dark)` 返回 `ThemeValues`**：

| 字段 | 亮色 + 模糊可用 | 亮色 + 模糊不可用 | 暗色（任意） |
|---|---|---|---|
| `gradient` | `linear-gradient(150deg,#8e9ff5,#c9a7e8 45%,#f3b6c2)` | 同左（保留） | `linear-gradient(150deg,#4a5680,#6b5a80 45%,#805a66)` |
| `cardBg` | `#ffffff30` | `#ffffff4d`（半透纯色，加深保证对比） | `#00000030` |
| `blur` | `blur(13px)` | `''`（**必须为空串**，Task 6 测试断言） | 模糊可用时 `blur(13px)`，否则 `''` |
| `border` | `1px solid #ffffff55` | 同左 | `1px solid #ffffff33` |
| `textPrimary` | `#ffffff` | `#ffffff` | `#ffffff` |
| `textSecondary` | `#ffffffd9` | `#ffffffd9` | `#ffffffb3` |
| `radiusCard` | `22` | `22` | `22` |
| `radiusChip` | `16` | `16` | `16` |
| `radiusIcon` | `12` | `12` | `12` |

**字号（fp）**：卡片标题 16、功能名 12、情境提示 10、分类 chip 12、全量列表项 14。ArkTS 卡片用 `fp`，不用 `px`。

---

## 4. 拼音/索引维度（`IOS_PINYIN_SPEC`，D3）

| # | 对齐 iOS 哪一点 | 取证来源（框架/符号/公开资料） | 鸿蒙卡片形态下的可行性取舍 | 依据层级 |
|---|---|---|---|---|
| P1 | 通讯录/Spotlight 的 section index 以 **A–Z 加 `#`** 收拢非字母开头项 | HIG「Index lists」；iOS 通讯录/音乐资料库可观察行为 | `PinyinUtil.initial` 返回 `'A'..'Z'` 或 `'#'`；`group` 返回 `Map<string, AtomicFunction[]>`，键序 A–Z 后 `#` 置末 | [S]/[I] |
| P2 | 中文按本地化排序键（拼音/注音/笔画）归入对应拉丁字母组，不是取首字节 | Apple 开发者文档「String localization / collation / `localizedStandardCompare`」；iOS 通讯录中文按拼音分组可观察 | 离线内置**常用汉字→首字母表**（仅覆盖能力库会出现的汉字），不引入第三方拼音库/依赖；覆盖不到的汉字归 `#` | [S]/[I] |
| P3 | 多音字按常用读音/词条惯例取排序键，无公开映射表 | 公开观察 + 本地化 collation 文档 | 显式列出多音字常用读音：重庆→`C`(chóng)、银行→`Y`(yín)、音乐→`Y`(yīn)、长大→`Z`(zhǎng)；未在表中的多音字按**最常用读音**首字母 | [I] |
| P4 | 数字/符号/emoji/非拉丁无字母排序键 → 杂项桶 | HIG「Index lists」；iOS 可观察行为 | 首字符为 `0-9`、emoji、标点、空白、空串、或非 A–Z/未覆盖汉字 → `'#'`；`'12306'`、`''`、emoji 均断言为 `'#'` | [I] |
| P5 | 空数据显示空态，不崩溃 | HIG「Empty states」 | `group([])` 返回空 Map；全量页显示空态文案；分类/建议区空时不占位符凑数 | [S] |

**定稿取值 — 映射规则（实现契约）**：

1. 取 `label` 的首个**非空白字符** `c`。
2. `c` 为 ASCII `A-Z`/`a-z` → 大写返回。
3. `c` 在离线汉字表 → 返回表定首字母（多音字按上表常用读音）。
4. 其余（数字、emoji、标点、其他脚本、空串） → `'#'`。
5. `initial('爱奇艺')='A'`、`initial('付款码')='F'`、`initial('B站')='B'`、`initial('12306')='#'`、`initial('')='#'`。
6. `group(items)`：按 `initial` 分桶，桶内按 `label` 排序，键按 `A..Z` 再 `'#'` 输出；`items=[]` → `size===0`。

---

## 5. 配置页重评估（§0.9 B3′）

`IOS_CATEGORY_SPEC` 结论 C2 表明 iOS 分类是**系统预置、自动归类、用户不可增删改**，仅可重排。据此**确认配置页维持最小配置**：

- 保留：类目顺序/类目内条目顺序调整（`CatalogEditor.reorderCategory(name, ids)`）、能力库本地替换入口（D5，`hdc push` 可替换配置文件）。
- **不做**：分类增删改、收藏、手动添加、推荐开关、用量查看/清空。
- 若未来 `IOS_CATEGORY_SPEC` 修订为支持用户自定义类目，再另走 Spec 修订并同步 `CatalogEditor` 接口；本期不补回。

---

## 6. 门槛自检（Stage −1 Step 6）

| 校验项 | 结果 |
|---|---|
| 四组最终取值齐备（含 `IOS_PINYIN_SPEC`） | ✅ §1–§4 |
| 分类 / 推荐 / 视觉三维度每条结论均按 B3 三栏格式有据可查 | ✅ §1 / §2 / §3 表格（+§4 拼音维度同格式） |
| 对齐层级按 §0.8 明确为「范式对齐而非机制复刻」且每条标了依据层级 | ✅ 文件头 + 每行 [S]/[I] |
| 不把推断冒充静态取证 | ✅ §2 R6 / §3 V2 / 各 [I] 行明确标注；机制级权重与类目判定算法列入「不在取证范围」 |
| 产品 Spec §5 / §6.2 / 分类体系 / §6.1 拼音占位值已同步 | ✅ 见同步编辑记录（产品 Spec 对应段落） |
| 产品 Spec §0.4 三条硬约束原文未变 | ✅ 未触碰 |
| 技术预研 Spec 未改 | ✅ 未触碰 |
| 研究计划处置 = C2「已并入本计划，不单独执行」并已加头部状态注记 | ✅ 头部注记已存在，Step 6 复核 |
| B3 用户终审 | ⚠️ `/goal` 明确「遇到需要选择的问题自行决策，不要问我」→ **执行时代为终审**（ledger Ruling），不打断用户；定稿取值均标注为可替换近似 |

---

## 7. 取值可替换性声明

`IOS_RANKING_SPEC` 的权重、`IOS_VISUAL_SPEC` 的色值/圆角/字号、`IOS_PINYIN_SPEC` 的汉字表均为**鸿蒙侧实现取值**（范式对齐近似），不是从 iOS 私有框架逆向得到的机制级数值。若后续能取得机制级取证（需 GB 级 Runtime/IPSW + 本机 REA 深度 provider，当前不可执行），可另走 Spec 修订替换；本期不因此阻塞定稿。
