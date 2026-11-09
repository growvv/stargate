# 鸿蒙平台功能聚合面板 — 技术预研设计（Spec）

- 日期：2026-11-07
- 阶段：**技术预研 / 方案设计**。本阶段不产出产品代码，不进入开发。
- 状态：设计已逐节确认，待用户审阅本文档。
- 平台口径：**纯 HarmonyOS NEXT**（ArkTS / Stage 模型 / HAP），目标 API 26 / HarmonyOS 7.0。
- 验证设备：`hdc` 真机 `5KPBB25927200695`（HarmonyOS 7.0.0.111, API 26）。

---

## 0. 目标、约束与成功标准

### 0.1 目标产出
一份经过讨论确认的**技术预研方案 / 架构设计文档**，外加**全面实测证据**。交付物是「设计 + 分层可行性结论 + 验证路径」，不是可运行产品。

### 0.2 产品定位（用户原述）
聚合各个 App 内部的**原子功能**，用户点击图标直达对应功能页面，不用完整打开整个 App；不是普通应用启动器。支持自定义分类（支付 / 购物 / 出行等分组）、内置推荐机制（依据单日、月度使用记录动态排序，高频功能优先展示在推荐区域）、手动添加与收藏自定义快捷入口。交互与布局参考 iOS 应用资源抽屉的分类、推荐范式。

### 0.3 约束
- 主形态：**独立 App 为主 + 服务卡片（Form Kit）延伸**。
- 分层：官方直达 → REA 逆向 / 外部反编译工具补全 → 注入 / 无障碍模拟点击兜底。
- 稳定性：URL Scheme、内部页面路由易随 App 版本失效，跳转失败回退 App 首页。
- 工具：本机 DevEco Studio / DevEco CLI（`hvigorw` / `hdc` / `ohpm`）；GitHub 复用轮子；Superpower skill 辅助。
- **暂不优先上架合规约束**；完全不需要考虑合规风险，首要是完成任务。
- 流程：先梳理完整技术思路、方案讨论确认，再进入开发。

### 0.4 成功标准
说清楚「点击图标直达 App 原子功能」在鸿蒙上有哪些路径、各路径可行性与代价、失效降级怎么做、推荐与分类怎么落地；且方案能被本机工具链验证。

### 0.5 平台约束（预研实证，与设计决策直接相关）
- HarmonyOS NEXT 的负一屏是系统桌面/智慧助手的一部分，**没有第三方嵌入 API**；三方现实可达的是服务卡片被用户添加到桌面/卡片区，而非接管负一屏。
- 真正的悬浮窗需 `ohos.permission.SYSTEM_FLOAT_WINDOW`（系统权限，三方不可得）；三方可用的是服务卡片与桌面快捷方式。
- **系统 Shortcuts 是给自己 App 配置桌面长按快捷项**（`shortcuts_config.json` → Want），不能用来拉起别的 App 的内部页；跨 App 直达靠目标 App 在 `module.json5` 里声明的 `skills`（Deep Link / App Linking / 显式 Want）。但 `bm dump -n <bundle> -s` 读到的**他人 App 的 shortcut 定义，其 `intents[].parameters` 是官方公开的原子功能参数**，可作为能力发现的数据源（见 2.1）。
- Android 的 Intent / 可导出 Activity / 无障碍模拟点击机制与鸿蒙 NEXT 的 Want / UIAbility / App Linking 不通用；Android 侧（本机另有一台 adb 设备与模拟器）仅作调研参照，不进入落地架构。
- 本机无 iOS 模拟器（Windows）；iOS 范式不通过实机验证，改用静态逆向路径（见 5.2）。

### 0.6 子系统分解
| # | 子系统 | 单一职责 |
|---|---|---|
| S1 | 直达能力层 | 路由描述 → 解析 → 执行 → 结果判定 |
| S2 | 能力来源与探测 | 官方入口清单、REA 逆向 / 外部反编译、GitHub 轮子调研 |
| S3 | 推荐引擎 | 日/月使用记录 → 动态排序 → 推荐区 |
| S4 | 分类 / 收藏 / 自定义入口 | 数据模型、持久化、编辑态 |
| S5 | 面板形态载体 | 独立 App / 服务卡片及其 UI |
| S6 | 稳定性与降级 | 版本失效检测 → 回退 App 首页 |
| S7 | 工程与验证 | DevEco 工具链、真机探针、验证矩阵 |

本阶段以**一份预研架构 spec** 覆盖全部子系统；实现阶段再按子系统拆成各自的 spec → plan → 实现周期。

---

## 1. 总体架构与组件边界

```
┌─────────────────────────────────────────────────────────────┐
│  载体层  Panel UI (独立 App / ArkUI)   ·   服务卡片 (Form Kit)   │
│   ├ 推荐区(动态排序)  ├ 分类分组(支付/购物/出行…)  ├ 收藏/编辑态    │
└───────────────────────────┬─────────────────────────────────┘
                            │ 只依赖下面两个接口
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
┌───────────────────┐                 ┌─────────────────────┐
│ S3 推荐引擎        │                 │ S4 目录与收藏        │
│ RankingEngine      │                 │ CatalogRepository   │
│ 日/月计数 → 排序   │                 │ 分类/收藏/自定义入口 │
│ 依赖: UsageStore   │                 │ 依赖: 持久化(KV/RDB)│
└─────────┬─────────┘                 └──────────┬──────────┘
          │ 读取                                  │ 读取
          ▼                                      ▼
┌─────────────────────────────────────────────────────────────┐
│ S1 直达执行层  LaunchDispatcher（核心，唯一出口）               │
│   input:  AtomicFunction     output: LaunchResult(成功/失败原因) │
│   ① 版本指纹校验 → ② 按 dataSource 优先级选路由 → ③ 执行       │
│       ④ 结果判定 → ⑤ 失败则降级到 App 首页                     │
└───────────────────────────┬─────────────────────────────────┘
                            │ 依赖能力清单
┌───────────────────────────┴─────────────────────────────────┐
│ S2 能力目录来源  CapabilityRegistry                           │
│  Producers: ShortcutScanner / SkillScanner / LinkFeatureScanner│
│             / ReaRouteProbe(REA+反编译补全) / ManualEntry       │
│  产出统一 AtomicFunction，带 source + confidence + appVersion  │
└─────────────────────────────────────────────────────────────┘
        ┌──────────────────────────────────────────────────┐
        │ S6 稳定性：FallbackPolicy / 版本指纹 / 失效侦测       │
        │ S7 工程：DevEco + hdc/aa/bm 探针 + 实测矩阵          │
        └──────────────────────────────────────────────────┘
```

**关键边界约定**
- **UI 层不直接接触 Want/URI**，只调 `LaunchDispatcher.launch(AtomicFunction)`；换载体（App → 卡片）不用改直达逻辑。
- **`AtomicFunction` 是唯一跨层契约**；所有数据源（官方 / 逆向 / 手工）归一化成它，推荐引擎与分类也只认它。
- **S1 是唯一执行出口**；降级、结果判定、埋点收敛在此，避免散落。
- **S2 的 producer 可插拔**：新增发现手段不改变 S1/S3/S4。

**核心数据契约（草案）**
```ts
interface AtomicFunction {
  id: string;                 // 稳定标识
  label: string; icon: Resource;
  bundleName: string;
  category: '支付'|'购物'|'出行'|string;
  routes: Route[];            // 按优先级排列，可多路由互为降级
  source: 'shortcut'|'linkFeature'|'scheme'|'rea'|'manual';
  confidence: number;         // 由 source 决定初始权重
  appVersionFingerprint?: string;  // 采集时的版本，用于失效判定
}
interface Route {
  kind: 'want'|'deeplink'|'applinking'|'shortcut-param'|'home';
  uri?: string; parameters?: Record<string,string>;
  abilityName?: string; moduleName?: string;
}
```

---

## 2. 数据源分层 + 全面实测矩阵

### 2.1 分层与优先级（技术路线 A：官方声明优先 + 按需逆向补全）

| 层 | 数据源 | 采集手段 | 初始 confidence |
|---|---|---|---|
| **L1 Shortcut** | `shortcuts_config.json` 的 `intents[].parameters` | `bm dump -n <b> -s` | 1.0 |
| **L2 系统意图** | `skills[].linkFeature` | `bm dump -n <b>` | 0.95 |
| **L3 自定义 scheme / App Linking** | `skills[].uris`（scheme / host / path / pathStartWith） | `bm dump -n <b>` | 0.85 |
| **L4 逆向补全** | `module.json` / `main_pages.json` / `modules.abc` / `sourceMaps.map` / `resources.index` | REA 清点容器 + xpanda/dayu 反编译 | 0.6 |
| **L5 兜底** | 注入 / 无障碍模拟点击 | 工程机调研 | 0.2，技术储备、非产品路径 |
| **L0 手工** | 用户自建 / 收藏 | 编辑态录入 | 1.0（用户显式） |

**选型逻辑（本次预研最重要的发现）**：L1 优先于 L3 —— shortcut 的 `parameters` 是 App 厂商自己定义的原子功能 ID（例如支付宝 `scan` → `appId=10000007`、`pay` → `20000056`），比拼 URI 稳定、语义明确。且纯鸿蒙 NEXT 下大部分原子功能入口**已由系统公开可读，无需逆向**；逆向价值收窄到两件事：① 找出 skills 声明里没写出的内部页面路由参数协议；② 无声明且无参数文档的功能。

### 2.2 技术路线选型（已确认）
- **A（采纳）**：以官方声明优先的声明式路由中台 + 按需逆向补全。稳定性最好、合规风险最低、被实测数据支撑。
- **B（不采纳）**：以逆向为中心的能力库。覆盖理论上最广，但维护成本 / 失效频率 / 合规风险最高，且与「官方已公开」的实证冲突，降级为 L4 补全手段。
- **C（不采纳，写入演进方向）**：双引擎 + 在线规则下发。降级体验最好，但预研阶段引入服务端属过度设计（YAGNI），留到产品化阶段。

### 2.3 全面实测矩阵
**范围（用户要求扩大）**：真机共 287 个 bundle，其中 45 个三方/商业 App + 3 个元服务 → **全量逐个扫描**；164 个华为系统 App 抽样（挑有 `linkFeature` 的）；47 个 `com.example` 示例 App 不逐个实测，仅作为本机可拆 HAP 样本用于 L4 方法验证。`aa start` 落点验证聚焦各品类代表样本（会真实拉起 App，不宜全量跑）。

**统一探针序列**：`bm dump -n <b>` → `bm dump -n <b> -s` → 归类 → `aa start -U <uri>` / `-a -b` / `-A -U -e` 真机拉起 → 用 uitest 控件树确认落点（目标页 / 首页 / 失败）。

| 品类 | 代表样本 | 待验证直达 |
|---|---|---|
| 支付 | 支付宝 | `scan`/`pay` shortcut 参数、`alipays://`（linkFeature Pay） |
| 社交 | 微信 / QQ | `id_scan`/`id_pay` shortcut、`weixin://`、`mqqapi` |
| 出行 | 高德 / 百度地图 / 12306 | `systemnav://navigation`、`baidumap://` + `Navigation/RoutePlan/PlaceSearch`、`cn.12306.uppayment` |
| 购物 | 京东 / 得物 / 拼多多 / 美团 / 点评 / 唯品会 / 天猫 / 转转 / 小红书 | `openjd`、`dewuapp`、`pinduoduo`、`imeituan`、`viprouter`、`zhuanzhuan`、`xhsdiscover` 及各自 `pathStartWith` 内部页 |
| 内容 | 抖音 / 快手 / B站 / 知乎 / 微博 / 爱奇艺 / QQ音乐 / 喜马拉雅 | `snssdk1128`、`kwai`、`bilibili`、`zhihu`、`sinaweibo`、`iqiyi`、`qqmusic`、`iting` |
| 工具 | WPS / 百度网盘 / 夸克 / UC | `ksowps`、`bdnetdisk`、`qklink`、`uclink` + `FileOpen` |
| 政务/运营商 | 个税 / 中国移动 | `etax`、`cn.10086.app` |

每条记录产出：`bundle / 入口 / 层 / 参数 / 实测落点 / 是否命中原子功能 / 失效备注`。全量扫描结果见**附录 A**。

### 2.4 探针纪律（Spike 边界）
- 全部为**一次性 throwaway 探针**：`hdc`/`aa`/`bm` 命令 + REA 只读分析，**不写产品代码、不改设备持久状态**。
- `aa start` 会真实拉起 App，属可见副作用，可 `aa force-stop` 复原；执行前先列清单。
- REA 会话用完即 `close_binary`。
- 声明层扫描已完成（附录 A）；执行层 `aa start` 落点验证留待实现阶段按清单执行，本阶段不逐一拉起 App。

---

## 3. 推荐引擎 / 分类收藏 / 数据流

### 3.1 推荐引擎（S3）
- **UsageStore**：本地持久化使用事件 `{functionId, timestamp}`，仅记「面板内点击直达」这一行为，不采集 App 内行为（无权限也无需）。
- **双窗口计数**：滚动维护 `dayCount`（当日）与 `monthCount`（近 30 日）。
- **排序评分**（可解释、无 ML、纯本地、不上云）：
  ```
  score = w_d * norm(dayCount)              // 当日频次
        + w_m * norm(monthCount)            // 月度频次
        + w_r * exp(-Δt / τ)                // 指数时间衰减（小时级 τ）
        + w_h * hourAffinity(f, nowHour)    // 时段亲和：该小时常用哪些功能
        + w_s * sceneAffinity(f, scene)     // 轻量场景：时段 + 最近使用序列推导
        + w_seq * seqBoost(f, lastN)        // 短序列关联：刚用 A 常有 B
        + w_p * pinnedBoost                 // 收藏/置顶
        + w_c * confidence                  // 路由可靠性（把稳定性内建进推荐）
  ```
- **时段/场景数据仍来自本地 UsageEvent**（按小时分桶统计），不申请位置/传感器、不上云；对应 iOS Siri 建议/App 资源库的「情境建议」思路 —— 用时间 + 频次 + 序列做**面板内排序**，不碰 App 内容。
- **冷启动**：无行为数据时按 `hourAffinity` 预置先验（早晨出行、午间支付、晚间购物）+ 分类默认序，随用量自动收敛到个人习惯。
- **多样性约束**：推荐区 Top-N 按类目打散，避免同类霸屏。
- 推荐区取 Top-N；**置信度高的路由优先**，等于把稳定性内建进推荐，而非等失败再降级。

### 3.2 分类 / 收藏 / 自定义入口（S4）
- 分组模型 `Category { id, name, order, functionIds[] }`，预置 支付/购物/出行/社交/工具…，可增删改排序。
- **手动添加**：用户录入自定义快捷入口（本质是 `source: manual` 的 AtomicFunction，允许填 URI 或从已扫能力里选）。
- **收藏**：`pinned` 标志，独立于分类，影响推荐评分。
- 持久化：`@ohos.data.relationalStore`（RDB）存能力与分类，`preferences`（KV）存轻量状态，用量事件追加写。

### 3.3 数据流（一次点击的完整链路）
```
用户点击图标
 → Panel UI 取 AtomicFunction，调 LaunchDispatcher.launch()
 → S1: 校验 appVersionFingerprint（与当前已装版本比对）
        → 版本变了：标记 routes 待复核，降 confidence
 → S1: 按 routes 优先级依次尝试（startAbility / openLink）
        → 成功：写 UsageEvent → 通知 S3 重算 → 刷新推荐区
        → 失败：FallbackPolicy 逐级降级 → 最终 openLink 到 App 首页
 → 结果回传 UI：成功 / 已降级 / 失败，给用户可见反馈
```

---

## 4. 稳定性 / 降级 / 兜底层（含绕过思路调研）

### 4.1 失效来源
`bm dump` 读到的 scheme / `pathStartWith` / shortcut 参数都是**随 App 版本可变的私有协议**；版本升级后 URI 参数、ability 名、`linkFeature` 都可能改。此外系统可能对未域名校验的 App Linking 弹选择框、目标 App 未安装、Ability 未导出等。

### 4.2 分层降级策略（S6，产品路径）
```
route[0] 失败 → route[1]（同功能另一入口）
     → 仍失败 → 降 confidence、标记待复核
     → 最终 → 打开 App 首页（openLink / startAbility home）
     → 用户可见反馈："已打开 X 首页，该功能入口可能已更新"
```
- **版本指纹**：采集时记录 `appVersionName/versionCode + bundle`；启动时比对，变化时自动触发「重扫该 App 的 skills/shortcut」，实现**自愈**而非单纯报错。
- **失效侦测**：连续 N 次失败 / 落点非目标页时，把该 route 降级并上报本地待复核队列。
- **结果判定**：`startAbility` 返回值 + 短暂前台状态观察；预研期可用 uitest 控件树辅助确认落点（见 4.5 / 5.3）。

### 4.3 HAP 逆向工具链（组合路径）
REA 的 `list_strings` / 反编译器不支持 HAP archive（Ghidra/IDA/Kuna 只吃可执行文件，Hopper 不支持 win32）。改为组合：
```
REA inspect_artifact   容器清点：module.json / main_pages.json / sourceMaps.map
                       / modules.abc / resources.index + 完整性证据
  ↓ 解压取出
xpanda (Apache-2.0)   HAP 提取 → abc 反编译 → ASM/伪代码 → patch/instrument
                       + resources.index → JSON
dayu (AGPL-3.0)       abc v13+ parser 交叉验证（仅作工具，不并入产品）
  ↓
内部路由常量 / 参数协议 → 回流 CapabilityRegistry 的 L4 producer
```
REA 负责可信的容器证据与完整性，外部轮子负责字节码语义；二者配合而非替代。已实证：REA 能完整清点样本 HAP（14 个节点），`module.json`（`abilities[].exported` + `skills`）、`main_pages.json`（页面路由表）、`sourceMaps.map`（原始 `.ets` 路径）均可读。

### 4.4 L5 兜底层完整评估（含绕过思路调研）

> **范围声明**：以下均为**技术机制与可行性分析**，限于本机工程机 / 自有设备、不落地、不针对真实第三方 App 实施攻击；结论明确标注为**技术储备、非产品路径**，并如实列出合规与安全风险。

**A. 注入 / Hook**
- 前提：`hdc smode` 切 root（工程机）、系统签名权限、或调试态 `aa attach` / `appdebug`。零售机普通三方 App 拿不到。
- 可行上限：ArkTS `modules.abc` 字节码替换 / native `lib*.so` hook（PLT/GOT、inline hook）、Ability 启动参数拦截。工程机内可改自身或调试态进程。
- 绕过思路调研（文档级）：调试桥 `aa attach` 进入 debug → 运行时替换路由参数；`hdc smode` + 重挂载后改已安装 HAP；Frida/自研 hook 框架拦截 `startAbility` 调用链。
- 代价：需 root / 解锁、每次系统更新失效、签名校验与完整性检查会阻断；**与上架合规直接冲突**。

**B. 无障碍模拟点击（AccessibilityExtensionAbility）**
- 机制：注册无障碍扩展 → 监听窗口事件 → `AccessibilityElement` 查找控件 → 注入点击/手势，模拟「打开 App → 点进某功能」。
- 可行上限：对自身 / 已授权场景可用；跨 App 自动化受系统权限与用户显式授权严格限制，控件树在商业 App（尤其自绘 UI / Flutter / 游戏）中常不可读。
- 绕过思路调研（文档级）：控件树不可用时的坐标点击 + 图像/OCR 定位；无障碍服务保活与授权引导；多步骤脚本编排。
- 代价：链路长、极度脆弱（UI 一改全断）、需引导用户开权限、功耗与体验差；**是上架审核重点限制对象**。

**C. 结论定调**
| 层 | 可行性 | 稳定性 | 合规 | 定位 |
|---|---|---|---|---|
| L1–L3 官方直达 | 已实证 | 高 | 无碍 | **主路径** |
| L4 逆向补全 | 已验证方法 | 中 | 低 | 补充 |
| L5 注入/无障碍 | 仅工程机 | 极低 | **高冲突** | **技术储备，非产品路径** |

L5 的存在意义是**说清「最坏情况下技术上限在哪」**，而不是把它做进面板。与「暂不优先合规约束」一致：如实评估，但不设计规避手段、不落地。

### 4.5 L5′ 官方测试通道（StarStack uitest 扩展 / 本机已有轮子）
- **来源核实**：StarStack（`E:\CodeE\vibe51\StarStack`）本身是 Windows 上的 HarmonyOS / ArkTS IDE（WinUI3 + WebView2/CodeMirror 6，C++/.NET），全仓无自研 uitest；所谓「uitest 扩展」实为**随包第三方工具链**：DevEco CLI `@deveco/deveco-cli-common` + `ui-verification-mcp` + OpenHarmony SDK。
- **机制**：PC 侧 `hdc shell uitest` daemon —— 按版本选 `uitest_agent_v*.so` 推到 `/data/local/tmp/agent.so`，起 `/system/bin/uitest start-daemon singleness &`，`hdc fport` 转发设备 `tcp:8012`；`uitest dumpLayout -p` 输出控件树 JSON（id/text/bounds/clickable），`ui layout --format json --mode simplified`，`uiInput click|longClick|swipe|text|keyEvent`，`ui click --id` 按 bounds 中心点击，`screenCap` + `hdc file recv` 截图。
- **无需 root、无需在目标 App 内嵌任何代码**，不用无障碍服务；但要求设备解锁 + USB 调试授权。
- **关键边界**：`@ohos.UiTest.d.ts` 全篇标 `@test` 与 `SystemCapability.Test.UiTest`，属**测试专用 syscap，普通三方发布 App 不可用**。因此 L5′ 的精确定位是**开发机经 hdc 驱动的外部测试工具**，不能作为产品内路径。
- **本机轮子**：`HapCore` / `HapTest` / `HapReplay` / `HMReplay` / `hapt` / `FuckHdc` / `hmdriver2`（MIT）六套工程，agent 版本 v1.0.8（StarStack 随包 v1.1.9 / v1.2.2），端口 8012 一致。
- **定位**：主要用于**预研验证层的落点判定**（控件树确认 `aa start` 究竟停在功能页还是首页）与调试期兜底；产品化需单独评估「PC 侧驱动 / 需调试授权」的边界。

---

## 5. 工程 / 验证 / 测试 / 风险 / 交付物

### 5.1 工程与工具链（S7）
- DevEco Studio + `hvigorw` / `hdc` / `ohpm`（本机均已可用）；目标 API 26 / HarmonyOS 7.0，真机 `5KPBB25927200695`。
- **预研阶段不建产品工程**；探针以脚本/命令形式放在独立 `probe/` 目录，明确 throwaway。当前产物：`probe/capability_scan.tsv`。
- **复用已有轮子**：本机六套鸿蒙自动化工程 + StarStack 随包 DevEco CLI 的 uitest 能力，作为验证层基础设施，减少重复开发。

### 5.2 GitHub / iOS 调研（重点近一年，已用 GitHub API 核实活跃度与 License）

| 方向 | 项目 | 核实事实 | 对本项目的价值 |
|---|---|---|---|
| HAP 反编译 | `asmjmp0/xpanda` | TS / Apache-2.0 / 159★ / 提交 **2026-11-06** | HAP 提取 → `modules.abc` 反编译 → ASM/伪代码 → patch/instrument → `resources.index` 解析；直接补 REA 短板 |
| HAP 反编译 | `hx1997/dayu` | Python / AGPL-3.0 / 139★ / 2026-09-12 | abc v13+ parser/decompiler，交叉验证；**AGPL 传染性，仅作工具不并入产品** |
| 鸿蒙 UI 自动化 | `yabi-zzh/hmdriver2` | Python / MIT / 2025-10-30 | 控件树 / xpath / 点击 / UI Inspector，本机已有副本 |
| 桌面/抽屉参考 | `openharmony/applications_launcher` | 官方主仓在 **Gitee** / Apache-2.0（GitHub 上仅镜像，1★） | `feature/appcenter`（应用抽屉）、`feature/bigfolder`（**智能文件夹 = 自动分类**）、`feature/form`（卡片）—— 正好对应分类 / 推荐 / 卡片 |
| App Linking | `HarmonyCandies/app_links_ohos`（MIT / 2025-06）、`webabcd/HarmonyDemo`（MIT / 2025-10） | 均已核实 | `skills` 配置、域名校验、拉应用/回网页的降级范式 |
| 元服务示例 | `liyufengrex/HarmonyAtomicService` | 102★ / 停在 2025-02 / **无 License** | 动态路由示例可参考，**代码不可直接复用** |
| iOS 范式 | `cbonello/flutter_app_intents`（MIT / 2026-04）、`Redth/Maui.Apple.PlatformFeature.Samples`（MIT / 2026-06） | 均已核实 | App Intents donation → Siri / Spotlight / Shortcuts 建议；Widget + App Intents 组合 |
| iOS 逆向 | `blacktop/ipsw`（MIT / **3870★** / 2026-11-06）、`blacktop/ipsw-skill`（MIT / 104★ / 2026-09）、`arandomdev/DyldExtractor`（MIT / 474★ / 已归档 2025-12） | 均已核实 | 下载并拆 iOS Simulator Runtime `.dmg` / IPSW → dyld_shared_cache → 私有框架提取 |

**iOS 主动逆向路径（不依赖真机、也不需运行模拟器）**
```
blacktop/ipsw 拉取 iOS Simulator Runtime .dmg / IPSW
  → 拆 dyld_shared_cache
  → 定位 App Library / Siri Suggestions / Proactive 私有框架二进制
  → REA 静态逆向 Mach-O（符号 / 字符串 / 调用关系）
  → 提炼分类与推荐的实现范式
```
辅以 App Intents donation / `AppIntentTimelineProvider.recommendations()` 等开源参考（`flutter_app_intents`、`Maui.Apple.PlatformFeature.Samples`、`TalissonVitorino/kmp-ios-skills` 的 WidgetKit timelines 文档）。

**如实标注的局限**
- 未找到开源的「鸿蒙功能直达 / 快捷方式聚合启动器」项目 —— 方向确为空白，印证预研价值；最接近的是 OpenHarmony 官方 Launcher 的 `bigfolder` 智能文件夹。
- 未找到专门实现 **Smart Stack 推荐排序**的开源库；iOS 侧可参考的是 App Intents donation / `recommendations()` 等**机制**，排序逻辑自行设计（见第 3 节）。
- `HarmonyAtomicService` 无 License、`DyldExtractor` 已归档，不可直接复用代码。
- 检索结果中大量镜像域名（github.co.uk / guthub.com / de.github.com / github.me 等）不可信；上表 canonical 仓库数据均经 GitHub API 核实。

### 5.3 验证方式
- **声明层**：全量 45 商业 App + 3 元服务 + 系统 App 抽样 → `bm dump -n` / `-s` 建入口清单矩阵（已完成，附录 A）。
- **执行层**：`aa start -U <uri>` / `-a -b` / `-A -U -e` 在真机逐样本验证落点，记录「命中原子功能 / 落到首页 / 失败」；**落点判定用 L5′ 的 uitest 控件树**（比只看 `startAbility` 返回码可靠）。
- **逆向层**：REA 清点 HAP + xpanda/dayu 解析 `modules.abc`，验证内部路由可提取。
- 三者结果汇总为可行性矩阵（附录 A 为声明层部分）。

### 5.4 测试策略（写进 spec，供实现阶段用）
- 单元：RankingEngine 评分 / 衰减 / 时段亲和 / 多样性、FallbackPolicy 各分支、AtomicFunction 归一化。
- 集成：真机上 `LaunchDispatcher` 对代表样本端到端（含降级到首页）。
- 回归：版本指纹变化时自动重扫；失效注入（故意改坏 URI）验证降级。

### 5.5 风险登记
| 风险 | 影响 | 缓解 |
|---|---|---|
| 私有路由随版本失效 | 直达失败 | 版本指纹 + 重扫自愈 + 多路由 + 降级首页 |
| 系统限制（负一屏 / 悬浮窗 / 无障碍 / @ohos.UiTest 测试 syscap） | 形态受限 | 锁定独立 App + 服务卡片；uitest 仅作开发机外部验证工具 |
| 合规（L5、聚合他人 App 入口） | 上架受阻 | 本阶段不优先；文档标注风险，主路径只用官方公开声明 |
| REA 反编译器不支持 HAP | 逆向手段受限 | 改「REA 清点 + xpanda/dayu 反编译」组合路径 |
| iOS 范式无实机 | 参考精度 | 改为 ipsw + dyld cache + REA 静态逆向；标注 Smart Stack 排序无开源实现 |
| GitHub 镜像域名 / 无 License 项目 | 误用不可复用代码 | 用 GitHub API 核实 canonical 仓库、License、活跃度 |

### 5.6 本阶段交付物（明确「不做什么」）
**交付**：① 本预研架构设计 spec（含以上 5 节）② 全面实测矩阵附录 ③ GitHub / iOS 调研笔记 ④ 分层可行性结论。
**不做**：产品工程、可运行面板、服务端、上架相关实现、L5 落地。
**之后**：用户审阅 spec 通过 → 才考虑 `writing-plans` → 实现计划 → 开发。

---

## 6. 分层可行性结论（预研结论）

1. **主路径成立**：纯鸿蒙 NEXT 下，跨 App 原子功能直达的官方能力（shortcut 参数 / `linkFeature` / 自定义 scheme / App Linking）**全部可由 `bm dump` 公开读取**，无需逆向。全量实测 48 个三方/元服务中 **77% 至少有一类官方入口**（77% 有自定义 scheme、46% 有 `linkFeature`、35% 有 shortcut）。
2. **shortcut 是最优数据源**：`intents[].parameters` 提供厂商自定义的原子功能 ID（支付宝 12 个、微信 3 个、百度地图 4 个等），语义明确、稳定性高于拼 URI，应作为 L1 优先。
3. **逆向的价值收窄**：L4 只需针对「官方声明不足」补盲（内部页面路由参数协议、11 个完全无声明的 App），由「REA 清点 + xpanda/dayu 反编译」组合完成；不应作为主路径。
4. **形态约束已明确**：三方无法嵌入负一屏、拿不到悬浮窗权限；主形态锁定独立 App + 服务卡片。
5. **稳定性可工程化**：版本指纹 + 自动重扫自愈 + 多路由降级 + 回退首页，是可落地的闭环。
6. **L5 仅技术储备**：注入 / 无障碍在工程机可行但与上架合规强冲突，不进入产品路径；L5′ 官方 uitest 通道是**开发机外部测试工具**（测试专用 syscap，三方 App 不可用），仅用于预研落点判定。

---

## 附录 A：全量声明层实测矩阵

数据源：`hdc -t 5KPBB25927200695 shell "bm dump -n <bundle>"` 与 `bm dump -n <bundle> -s`，采集于 2026-11-07。原始 TSV：`probe/capability_scan.tsv`。
口径：仅统计非 `https/http/file/content` 的自定义 scheme；`linkFeature` 排除空值；`shortcut` 为 shortcut id 列表；`path / pathStartWith` 列如实列出扫描所得值（原始 TSV 中该列截断至 160 字符）。表中 `—` 表示三类官方声明均未读到。

| bundle | 自定义 scheme | linkFeature | shortcut id | path / pathStartWith（节选） |
|---|---|---|---|---|
| cn.gov.tax.its.hm | etax,its,store | | | home |
| cn.icheny.wechat | — | — | — | — |
| cn.wps.office.hap | ksodoccenter,ksoet,ksopdf,ksoqing,ksowpp,ksowps,ksowpscloudsvr,storage | AppStorageMgmt,FileOpen | | clearcache |
| com.alipay.mobile.client | alipay,alipayauth,alipaymo,alipayqr,alipayre,alipays,alipayshare,apmqpdispatch,taobaooauth12501616 | Login,Pay,Share | bus,collect,delivery,forest,jiankangma,manor,more,pay,scan,sports,transfer,yibaoma | /app,/h5,app,h5,p/s/i,p/s/ulink,share |
| com.amap.hmapp | amapuri,qqopenapi,systemnav,taobaooauth21792629,ut.34657035 | Navigation,PlaceSearch,RoutePlan | | applink/ |
| com.atomicservice.5765880207854893925 | atomwbmain | | | |
| com.atomicservice.6917568146765197900 | — | — | — | — |
| com.atomicservice.6917576281833361266 | — | — | — | — |
| com.baidu.hmmap | baidumap | Navigation,PlaceSearch,RoutePlan,getCuid | shortcut_go_company,shortcut_go_home,shortcut_route_plan,shortcut_taxi | |
| com.baidu.netdisk.hmos | bdnetdisk,qqopenapi | FileOpen | | embed/listenshare,fcb/s,s,wap/snsdeeplink |
| com.bitmap.image | — | — | — | — |
| com.chinamobile.cmcc | cn.10086.app,paygatewaysdk,qqopenapi,richpush | | shortcut_1,shortcut_2,shortcut_3,shortcut_4 | A,activity-UAT/transit/universalLink.html,activity-gray/transit/universalLink.html,activity/transit/universalLink.html |
| com.chinarailway.ticketingHM | cn.12306,cn.12306.comm,cn.12306.uppayment,com.12306,jump,mpaasscheme | | shortcut_1,shortcut_2,shortcut_3,shortcut_4 | landing,longlink |
| com.dewu.hos | dewuapp,dewulink,dewuunionpay,qqopenapi | | | c,h5-identify,mdu,note,page/external,s,t/E |
| com.dongqiudi.hmn.news | dongqiudi,qqopenapi | | | |
| com.droi.tong | droitong,qqopenapi | AppStorageMgmt,FileOpen | | |
| com.ericple.ohbill | — | — | — | — |
| com.eternaljust.msea.huawei | — | — | — | — |
| com.harmonyresearch.mockweibo | — | — | — | — |
| com.hupu.heroes | huputiyu,qqopenapi,w1fzj1 | | | s |
| com.jd.hm.mall | jdanalytics,jdpay,jdpaynuccpay,openApp.jdMobile,openapp.jdmobile,openjd,qqopenapi,storage,uppaymerchant | AppStorageMgmt,Login | | clearcache,v/ |
| com.kuaishou.hmapp | kwai,qqopenapi | AppStorageMgmt | scan,search,shoot | storagePage |
| com.larus.nova.hm | cjsign,doubao,doubaoUPPay482431Share | | call_phone,open_camera | flow/chat |
| com.lfr.myapplication | — | — | — | — |
| com.meituan.takeaway | meituanunionpay,meituanwaimai,qqopenapi | Login | search | |
| com.qiyi.video.hmy | iqiyi,iqiyi_clear,qqopenapi | AppStorageMgmt | id_shortcut_for_puremode | app/register_business,calendar,clear_app_storage,m/playShare,player,register_business,webview |
| com.quark.ohosbrowser | qklink,qqopenapi,storage,taobaooauth34813412,uclink,ut.34813412 | AppStorageMgmt | | clearCache,knockShare |
| com.samples.customdrawsample | — | — | — | — |
| com.sankuai.dianping | dianping,meituanunionpay,qqopenapi | Login | short_cut_one | hobbit,qr/explain,qrcode/dprebate,qrcode/rebate |
| com.sankuai.hmeituan | imeituan,meituanunionpay,qqopenapi | | shortcuts_display_order,shortcuts_display_scan,shortcuts_display_search | download/app.html |
| com.sina.weibo.stage | qqopenapi,sinaweibo | AppNotificationMgmt,AppStorageMgmt,Login | | auth |
| com.speaklab.jingmo | — | — | — | — |
| com.ss.hm.ugc.aweme | accountsdk1128,cjsign,douyinUPPay1128Share,douyinopensdk,dypay1128,snssdk1128,sslocal,storage,ttcjpay | AppStorageMgmt,Pay | clear_cache_widget_v1,clear_cache_widget_v1_livestyle,clear_cache_widget_v2,clear_cache_widget_v2_livestyle,live_1*1_widget | authorize,clearcache,ulink |
| com.tencent.hm.qqmusic | qqmusic,qqopenapi | AppStorageMgmt,FileOpen,Login | shortcut_local,shortcut_recent,shortcut_recognize,shortcut_search | |
| com.tencent.mqq | amapuri://,baidumap://,midaspay,mqqapi,qqmap://,qqopenapi,tencent,wtloginmqq | AppStorageMgmt,Login,Pay | | auth,direction,plan,qlogin,routePlan,storage |
| com.tencent.wechat | weixin,wxopensdk,wxweappsdk | Pay | id_pay,id_qrcode,id_scan | |
| com.tmall.tmall4hmos | alipayLogin34612052,push,taobaossoLogin34612052,tmall | | | |
| com.uc.mobile | qqopenapi,storage,taobaooauth34695614,uclink,ut.34695614 | AppStorageMgmt | | clearcache,knockShare |
| com.usb.right | — | — | — | — |
| com.vip.hosapp | viprouter,vipsdk,vipshop,vipshopuppaymerchant | | id_order_track,id_pic_search,id_search | deeplink |
| com.wifiservice.portallogin | Portal | | | |
| com.wuba.life | passport.58,wbmain,wmdacheck.28805061631152 | | | |
| com.ximalaya.ting.xmharmony | iting,qqopenapi,storage | AppStorageMgmt | | clearcache |
| com.xingin.xhs_hos | clear_demo,qqopenapi,xhsdiscover,xhsuppaymerchant | AppStorageMgmt,Login | | activity/sem/kratos,customer_service/store,discovery/item/,goodsForCall/,hina/livestream,mobile/login,oia,open/new_sdk/,open/sdk/,post_new_note/,qq_conn/1005071 |
| com.xunmeng.pinduoduo.hos | httpssn,pddopen,pinduoduo,pinduoduoalipays,pinduoduounionpay,qngaccv79cv29i,qqopenapi,weixinn | | | |
| com.zhihu.hmos | qqopenapi,setting,zhihu | AppNotificationMgmt,Login | company,home | notification |
| com.zhuanzhuan.hmoszz | jdpauthjdjr132536886004,jdpauthjdjr134003140002,jdpauthjdjr134003140003,msepay,qqopenapi,zhuanzhuan,zzuppay | | shortcuts_id_msg,shortcuts_id_publish,shortcuts_id_search | zz/ |
| yylx.danmaku.bili | bilibili,qqopenapi | AppStorageMgmt | id_history,id_shortcut_search | /storage-manager,conversation,ohos |

**覆盖率统计（48 个三方/元服务）**
| 指标 | 数量 | 占比 |
|---|---|---|
| 有自定义 scheme | 37 | 77% |
| 有 `linkFeature` | 22 | 46% |
| 有 shortcut | 17 | 35% |
| **至少一类官方入口** | **37** | **77%** |
| 完全无官方声明（需 L4/L5 补盲） | 11 | 23% |

无声明清单：`cn.icheny.wechat`、2 个 atomicservice、`com.bitmap.image`、`com.ericple.ohbill`、`com.eternaljust.msea.huawei`、`com.harmonyresearch.mockweibo`、`com.lfr.myapplication`、`com.samples.customdrawsample`、`com.speaklab.jingmo`、`com.usb.right`（多为示例 / 元服务 / 小众 App）。

**已验证的测量仪器**
- `hdc -t <dev> shell "bm dump -a"` → 287 个 bundle 清单。
- `bm dump -n <b>` → `skills[].uris`（scheme / host / path / pathStartWith）、`linkFeature`、`abilities[].exported`。
- `bm dump -n <b> -s` → shortcut 的 `id` 与 `intents[].parameters`，例如支付宝 `scan` → `appId=10000007`、`pay` → `20000056`、`bus` → `200011235`；微信 `id_qrcode` → `shortCutKey=shortCutMyQrCode`。
- `aa start` 参数：`-U <uri>`（Deep Link）、`-a <ability> -b <bundle>`（显式）、`-A <action> -U <uri> -e <entity>`（隐式 Want）、`--ps/--pi/--pb`（参数注入）。
- `bm dump -s` 必须带 `-n <bundle>`，否则报错。
- REA `inspect_artifact` 对 HAP 可完整清点；`list_strings` 不支持 archive 目标（Ghidra 未配置 / Hopper 不支持 win32 / IDA 未配置 / Kuna 未配置）。

---

## 附录 B：参考资源（canonical URL）

- HAP / abc 反编译：<https://github.com/asmjmp0/xpanda>、<https://github.com/hx1997/dayu>
- 鸿蒙 UI 自动化：<https://github.com/yabi-zzh/hmdriver2>
- OpenHarmony 官方 Launcher：<https://gitee.com/openharmony/applications_launcher>（Apache-2.0）、架构解析 <https://deepwiki.com/openharmony/applications_launcher/1-openharmony-launcher-overview>
- App Linking：<https://github.com/HarmonyCandies/app_links_ohos>、<https://github.com/webabcd/HarmonyDemo>
- 元服务示例：<https://github.com/liyufengrex/HarmonyAtomicService>（无 License，不可复用）
- iOS App Intents / Widget：<https://github.com/cbonello/flutter_app_intents>、<https://github.com/Redth/Maui.Apple.PlatformFeature.Samples>
- iOS 静态逆向：<https://github.com/blacktop/ipsw>、<https://github.com/blacktop/ipsw-skill>、<https://github.com/arandomdev/DyldExtractor>、<https://github.com/mroi/apple-internals>
- iOS 私有框架逆向方法：<https://deepwiki.com/reels-research/iOS-Private-Frameworks/4-reverse-engineering-process>
- SpringBoard / App Library 内部：<https://sidorov.tech/en/all/digging-into-springboard>
