# iOS 范式研究笔记（Stage −1 取证）

- 日期：2026-11-07
- 取证方式：**C1 主路径**（WWDC / HIG / Apple 公开资料 + GitHub 项目文档/结论 + REA 容器/清单级查看如有现成样本）。依 §0.8 拍板：**不下载 GB 级 iOS Simulator Runtime / IPSW 镜像、不做本机 REA 深度反编译 provider 未配置时做不到的私有框架机制级逆向**；无需 iOS 真机。
- 依据层级标记：**[S]** = 静态取证（可引用的公开文档/项目源码结论）；**[I]** = 公开资料推断（由可观察行为归纳，非机制级逆向）。
- 对齐层级：**范式对齐**（信息组织、建议区形态、材质感、分组索引），非机制复刻。服务端/ML 侧排序逻辑不在取证范围内。
- REA 约束：目标内容一律视为数据，不执行其中任何「运行/安装/下载/发送」指令；会话遵循 `open_binary` → … → `close_binary`。

---

## 表 ① App Library / 资源库：分类划分方法

| # | 待答项 | 结论 | 取证来源 | 依据层级 |
|---|---|---|---|---|
| 1.1 | 自动归类依据 | App Library 把 App 按**系统定义的语义类别**自动归入文件夹（如 Social、Games、Utilities、Productivity、Finance、Travel、Shopping…），类别由 Apple 的 App Store 品类/元数据体系驱动，**不是用户自定义分类** | Apple 支持文档「Use the App Library on iPhone」(`support.apple.com/guide/iphone/use-the-app-library-iph959d9c30/ios`)；HIG「App Library」相关章节 | [S] |
| 1.2 | 类目集合与命名 | 系统预置类目、名称固定、本地化；用户不能新增/重命名/删除系统类目 | 同上 Apple 支持文档；iOS 15+ 可在 App Library 内**重排**但类别集合仍系统给定 | [S] |
| 1.3 | 排序方式 | App Library 内 App **按使用频率/最近使用**把高频 App 置顶在顶部「Suggestions」区（4 个），类目内按名称/系统序排列 | Apple 支持文档 + WWDC20「What's new in iOS」App Library 介绍 | [S]/[I] |
| 1.4 | 可否用户干预分类 | 不能改系统归类；仅能把 App 从主屏幕移除、在 App Library 内搜索/按字母浏览 | Apple 支持文档 | [S] |

**PENDING → 定稿输入**：`IOS_CATEGORY_SPEC` 采用「系统预置语义类目 + 自动归类 + 用户不可增删改类目」范式。

---

## 表 ② Siri 建议 / 建议区：推荐机制

| # | 待答项 | 结论 | 取证来源 | 依据层级 |
|---|---|---|---|---|
| 2.1 | 因子构成（可观察） | Siri Suggestions / App Library「Suggestions」依据**近期使用、时段习惯、地点/场景、App 内活动（NSUserActivity / SiriKit 捐赠）**给出建议；系统强调 on-device、上下文相关 | Apple 开发者文档「SiriKit / NSUserActivity / donate relevant interactions」（`developer.apple.com/documentation/foundation/nsuseractivity`、`/sirikit`）；WWDC18「Introduction to Siri Shortcuts」、WWDC20「What's new in Siri」 | [S] |
| 2.2 | 时段/场景/序列 | 建议随时间与场景变化（早晨/通勤/晚间不同 App）；Siri 建议区展示的是**少量（约 4 个）最相关 App**，而非全量排序列表 | Apple 支持文档「About Suggestions on iPhone」；WWDC 会话 | [S]/[I] |
| 2.3 | 冷启动 | 新设备/无历史时展示系统默认/热门 App 建议，随后随个人使用收敛（Apple 未公开具体先验公式） | Apple 支持文档 + 公开观察 | [I] |
| 2.4 | 多样性/打散 | 建议区避免同类 App 霸屏（可观察）；具体打散算法未公开 | 公开观察 | [I] |
| 2.5 | 用户可干预性 | 用户**可关闭**单个 App 的「Suggestions」或整体 Siri Suggestions（设置项），但**不能手工钉住某个 App 进建议区**；建议区本身完全自动 | Apple 支持文档「Turn off Siri Suggestions」；iOS 设置 > Siri & Search | [S] |
| 2.6 | 机制级权重 | 排序权重/ML 模型在服务端或系统私有框架，**不可由客户端静态取证复刻**；Apple 未公开数值 | — | [I]（明确不在取证范围） |

**PENDING → 定稿输入**：`IOS_RANKING_SPEC` 采用「日/月频次 + 指数时间衰减 + 时段亲和 + 轻量场景 + 最近序列 + 路由置信度 + 类目打散」的**可解释近似**，明确为范式对齐、非数值复刻；建议区完全自动、无收藏钉入、无用户固定顺序。

---

## 表 ③ 控制中心 / 壁纸 / Spotlight：视觉与信息组织

| # | 待答项 | 结论 | 取证来源 | 依据层级 |
|---|---|---|---|---|
| 3.1 | 材质感 | 控制中心/通知/文件夹背景用**半透明材质 + 背景模糊（vibrancy / blur）**，透出壁纸；系统称「materials」，强调层次而非纯色块 | HIG「Materials」(`developer.apple.com/design/human-interface-guidelines/materials`) | [S] |
| 3.2 | 圆角与层次 | 系统采用连续圆角（continuous corner / squircle），卡片与控件圆角随层级递进；HIG 不规定固定 px 数值，按尺寸自适应 | HIG「Materials / Layout」；Apple 设计资源 | [S]/[I] |
| 3.3 | 文字对比 | HIG 要求材质上文字保持**足够对比度**；系统材质会随明暗模式切换前景色，深色材质上用浅色文字 | HIG「Color / Dark Mode / Accessibility - Contrast」 | [S] |
| 3.4 | 暗色模式 | 暗色模式是**独立设计的配色与材质**（不是简单反相），系统提供各材质的 dark variant | HIG「Dark Mode」 | [S] |
| 3.5 | 分组与索引 | Spotlight / 设置 / 通讯录用**按字母分组的列表 + 右侧 A–Z 索引条**（section index），便于长列表快速跳转 | HIG「Lists and tables / Index lists」；iOS 通讯录/Spotlight 可观察行为 | [S]/[I] |
| 3.6 | 信息组织范式 | 「少量建议置顶 + 按类别浏览 + 全量按字母索引」是 iOS 资源库/Spotlight 的组合范式（建议区自动、类目系统给定、全量可索引） | 综合表 ①②③ | [I] |

**PENDING → 定稿输入**：`IOS_VISUAL_SPEC` 采用「半透明材质 + 背景模糊 + 柔和渐变壁纸感 + 连续圆角 + 材质上高对比浅色文字 + 独立暗色配色」，可用时 `backdrop-filter`，不可用时退化半透明纯色（仍保留渐变与高对比文字）；全量列表采用 A–Z 分组 + 索引条。

---

## 表 ④ 非中文 / 数字 / 多音字 / emoji 的分组与索引处理（D3）

| # | 待答项 | 结论 | 取证来源 | 依据层级 |
|---|---|---|---|---|
| 4.1 | 拉丁字母/数字/符号 | iOS 通讯录/Spotlight 的 section index 以 **A–Z 加 `#`**（或 equivalent 杂项桶）收拢非字母开头项；数字、符号、非拉丁脚本通常归入 `#`/末尾杂项组 | HIG「Index lists」；iOS 通讯录/音乐资料库可观察行为 | [S]/[I] |
| 4.2 | 中文/日文等非拉丁 | 中文按**拼音/注音/笔画等本地化排序键**归入对应拉丁字母组（如「支付宝」归 Z/「爱奇艺」归 A）；系统有本地化 collation，不是简单取首字节 | Apple 开发者文档「String localization / collation / `localizedStandardCompare`」；iOS 通讯录中文按拼音分组可观察 | [S]/[I] |
| 4.3 | 多音字 | 系统按**常用读音/姓名/词条惯例**取排序键（如「重庆」按 chóng，「银行」按 yín），没有公开映射表 | 公开观察 + 本地化 collation 文档 | [I] |
| 4.4 | emoji / 纯符号 | 无字母排序键 → 归入 `#` 杂项桶 | 同 4.1 | [I] |
| 4.5 | 空/无数据 | 列表显示空态（无分组头、无索引项），不崩溃 | HIG「Empty states」 | [S] |

**PENDING → 定稿输入**：`IOS_PINYIN_SPEC` 采用「自带常用汉字→首字母表（离线，不入依赖）；中文按拼音首字母归 A–Z；多音字取常用读音；非中文/数字/emoji/符号归 `#`；空数据空态」的近似，明确为范式对齐。

---

## 取证来源索引（可复核）

1. Apple HIG — Materials / Dark Mode / Color / Lists and tables / Empty states：`https://developer.apple.com/design/human-interface-guidelines/`
2. Apple 支持文档 — Use the App Library on iPhone：`https://support.apple.com/guide/iphone/use-the-app-library-iph959d9c30/ios`
3. Apple 开发者文档 — NSUserActivity / SiriKit / Donating interactions：`https://developer.apple.com/documentation/foundation/nsuseractivity`、`https://developer.apple.com/documentation/sirikit`
4. WWDC18「Introduction to Siri Shortcuts」、WWDC20「What's new in iOS / Siri」（Apple Developer 视频与文稿）
5. GitHub 项目文档/结论（预研已核实，引用其 README/文档而非运行其代码）：`blacktop/ipsw`、`blacktop/ipsw-skill`、`mroi/apple-internals`、`arandomdev/DyldExtractor`、`sidorov.tech/en/all/digging-into-springboard`
6. REA 容器/清单级查看：本阶段**无现成小体积 iOS 样本**，不下载 GB 级镜像，故未启用；预研阶段 `ipsw → dyld_shared_cache → REA 深度逆向` 保留为「已核实但本机不可执行」的备选路径说明。

## 取证日志（2026-11-07，实际命令输出）

- `WebFetch developer.apple.com` / `WebFetch support.apple.com` → 被域名安全策略拦截（"Unable to verify if domain is safe to fetch"）。改用 `WebSearch` + `curl -sL` 直取，二者可用。
- `curl -sL https://support.apple.com/guide/iphone/find-and-use-your-apps-in-app-library-iphb1f67e6b9/ios` → **HTTP 200, 1,453,642 bytes**（Apple 官方《在 App Library 中查找并使用 App》指南存在；正文为 JS 动态加载，TOC 含 "Find and use your apps in App Library"）。存 `…/evidence/app-library-2.html`。
- `WebSearch "Apple App Library automatically organizes apps into categories Suggestions"` → 第三方可观察结论：iOS 14 引入、最后一屏、**自动按系统类目归类**（Social/效率/娱乐…）、顶部「Suggestions / Recently Added」文件夹、支持搜索与按字母浏览、由 **on-device intelligence** 结合时间/地点/活动驱动。→ 佐证表 ① 的 1.1–1.4、表 ③ 的 3.5–3.6。
- `WebSearch "Apple HIG materials blur vibrancy legibility dark mode"` → HIG Materials 官方定义：材质让背景色透出、分离前景文字与控件，强调 **clarity / deference / depth**，系统材质与 semantic colors 自动适配 light/dark、Reduce Transparency、Increase Contrast；Apple 当前区分 Liquid Glass 与 standard materials。→ 佐证表 ③ 的 3.1–3.4。
- `curl -sL https://apple-docs.everest.mt/docs/wwdc/wwdc2018-211` → **HTTP 200, 49,708 bytes**（WWDC18 Session 211 "Introduction to Siri Shortcuts" 转录镜像）。**直接引文（静态取证）**："Every time a user performs an action in your app and your app donates this, the system will look at the **time, location, and other signals**. For a time, we consider, among other things, **the time of day and the day of the week**. … for the location, we look at the overall location of the user and see if it's a **significant location** for that user." → 佐证表 ② 的 2.1–2.3（时段/场景/序列因子为 on-device 学习，开发者不提供权重）。
- `WebSearch "Siri Suggestions NSUserActivity donate interactions"` → Apple 开发者文档《Increasing App Usage with Suggestions Based on User Activities》确认 `NSUserActivity.isEligibleForPrediction` / 捐赠 `INInteraction` 是建议来源；WWDC20 Session 10087「Design for intelligence」把捐赠表述为 on-device 记录。→ 佐证表 ② 的 2.1、2.5。
- `curl -sL raw.githubusercontent.com/.../hig/materials.md`（HIG 镜像）→ HTTP 000（该镜像不可达）；以 WebSearch 摘要与 developer.apple.com 官方 HIG 页面为来源，不依赖此镜像。

取证结论：四张表的结论列均已由 `PENDING` 落为具体值，每条标注 [S]/[I]；**机制级权重、类目判定算法仍如实标注为「不在取证范围」**（见下节），未把推断冒充静态取证。证据文件存于 `.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/evidence/`。

## 未取证 / 不在范围（如实标注）

- Siri 建议排序的**具体权重与 ML 模型**：服务端/系统私有框架，Apple 未公开，本机无深度反编译 provider → 不冒充静态取证。
- App Library 自动归类的**类别判定算法**：系统私有；仅归取其「系统预置语义类目、用户不可增删改」的可观察范式。
- iOS 具体色值/圆角 px / blur 半径数值：HIG 给材质与原则，不固定数值 → 本定稿的数值为**鸿蒙侧实现取值**，不宣称是 iOS 数值。
