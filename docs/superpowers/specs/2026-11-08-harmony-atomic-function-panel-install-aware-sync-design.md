# 鸿蒙功能聚合面板 — 已安装应用感知 / 能力模板 / 定时刷新 设计 Spec（P7）

> **状态：设计稿，待用户过目。本轮只写文档，不改任何产品代码，不改技术预研 Spec，不改既有产品 Spec 正文。**
> 日期：2026-11-08
> 关联主文档：`docs/superpowers/specs/2026-11-07-harmony-atomic-function-panel-product-design.md`
> 关联既有决策：主文档 §0.5 决策变更记录 / §0.6 A2 / §0.7 D5 / §0.9 B2′ / §1.4 平台边界 / §4.3 失败处理 / §6.1 数据来源 / §7 产品层覆盖

> **引用约定（重要）**：本文与**主文档** `2026-11-07-harmony-atomic-function-panel-product-design.md` 的章节号有重叠（两篇都有 §4.3 / §6.1–6.4 / §7），含义不同。故：
> - **凡写作 `§N` 或 `主文档 §N` 的，一律指主文档**（产品定义 Spec）的章节；
> - **凡写作 `本 Spec §N` 的，指本文**对应章节；
> - 主文档 §4.3 = 反馈与失败处理、§6.2 = 推荐引擎、§7 = 产品层覆盖；本文 §4.3 = 系统应用口径、§6.2 = 与 D2 解耦、§7 = 错误处理与稳定性。请勿交叉误读。

---

## 0. 背景与目标

### 0.1 用户诉求（2026-11-08 两条消息要点）

1. 提高 App / 卡片的**稳定性**，减少错误。
2. 卡片应有**定期刷新机制**：感知本机**新装 / 卸载**了什么应用，把对应**子功能**自动**添加或删除**到卡片上。
3. 装到**不同手机**上应**自动检测、自动分析、自动适配**，不是写死一份清单。
4. 先把**常见应用**列出来**作为模板**；**没装该应用，就不出现对应图标/功能**。
5. 打磨产品、提升用户体验。

（口径澄清：用户原文「它们的职工」按上下文理解为「它们的子功能 / 原子功能」。若有误请纠正。）

### 0.2 成功标准（可验收）

| # | 标准 | 验收方式 |
|---|---|---|
| S1 | 只装了微信 / 支付宝的手机上，卡片与三个内页**不出现**淘宝 / 京东等未安装应用的图标 | `uitest dumpLayout` 文本计数 + 截图目视 |
| S2 | 装上模板内某应用后，**下一次刷新**（平台周期 ≤30 分钟，或打开 App / 点卡片时立即）出现对应功能 | 真机装包前后截图对比 |
| S3 | 卸载某应用后，下一次刷新对应功能**消失**，不留死图标 | 同上 |
| S4 | 探测失败 / 权限异常 / scheme 未声明时，卡片**不崩溃、不误报空态、不误显示** | 真机 + Node 单测 |
| S5 | 未安装应用导致的「点了才发现没装」死链数为 **0** | 真机逐项点检 |
| S6 | 直达失败仍按 §4.3 **明确报告 + 失效小圆点**，不回退首页、不试其他路由 | 既有失败链路回归 |

### 0.3 非目标（明确不做）

- **不枚举全机已安装应用**：普通三方 HAP 拿不到该权限（见本 Spec §1）。
- **不承诺秒级「装完立刻变」**：平台卡片刷新最快 30 分钟；即时性靠「打开 App / 点卡片」主动刷新补足。
- **不针对真实第三方 App 做注入 / 无障碍攻击**（L5 仅预研层文档结论，不落地）。
- **不把未实测的 scheme 冒充「已验证可直达」路由**。
- **不做服务端 / 云端模板下发**：沿用 §0.7 D5「本地可替换配置文件」。
- **不引入手动添加 / 收藏 / 推荐开关**（§2.3、§0.7 B2 已移出第一期）。
- **不改技术预研 Spec**（既有硬约束）。

---

## 1. 平台事实（本机 SDK 查证，决定能力边界）

查证对象：本机 `D:/Huawei/command-line-tools/sdk/default/openharmony`（API 26 / HarmonyOS 7.0），真机 `5KPBB25927200695`。证据索引见附录 A。

| 能力 | API / 配置 | 对本项目可行性 | 依据 |
|---|---|---|---|
| 枚举全机已安装应用 | `bundleManager.getAllBundleInfo` 等 | **不可行**：公开 `bundleManager.d.ts` 无全量枚举导出 | 附录 A-1 |
| 查询指定包名信息 | `getBundleInfo(bundleName, flags)` | **不可行**：需 `ohos.permission.GET_BUNDLE_INFO(_PRIVILEGED)`，SDK 原文「requires to be a system application」 | 附录 A-2 |
| 探测某 link 能否打开 | `bundleManager.canOpenLink(link)` → `boolean` | **可行**：API 12+、`@atomicservice`、无需权限；scheme 须预先声明在 `querySchemes` | 附录 A-3 |
| scheme 白名单 | `module.json5` → `module.querySchemes` | **可行**：数组、≤50 项、每项 `^[a-zA-Z][0-9a-zA-Z+.-]*`、≤128 字符 | 附录 A-4 |
| 安装 / 卸载广播 | `COMMON_EVENT_PACKAGE_ADDED / REMOVED / REPLACED / FULLY_REMOVED` | **不可作主触发**：系统发布；普通应用动态订阅仅进程存活期有效，卡片提供方常被冻结 | 附录 A-5 |
| 卡片周期刷新 | `form_config.json` → `updateDuration`（单位 30 分钟，最快 30 分钟） | **可行** | 附录 A-6 |
| 定点刷新 | `scheduledUpdateTime`（当前 `"10:30"`） | **可行，但与周期刷新互斥** | 附录 A-6 |
| 主动刷新 | `formProvider.updateForm` / `setFormNextRefreshTime` | **可行**（工程已在用） | 附录 A-7 |

### 1.1 两个直接决定设计的发现

- **发现 1（周期刷新其实没在跑）**：SDK `forms.json` 原文「You can select **either** refresh **or** refresh at a fixed point. **If both are configured, the card is refreshed at a scheduled time.**」当前 `form_config.json` **同时**配了 `scheduledUpdateTime:"10:30"` 与 `updateDuration:1`，按文档**定点优先**，即一天只在 10:30 刷一次。真机 `hidumper -s FormMgr` 曾观察到 `updateDuration [1800000]`（=30 min）、`updateAtHour [10]`、`updateAtMin [30]`、`isCountTimerRefresh [0]`、`refreshCount [3]`，与该推断一致但不构成充分证明 —— **列为 Task 0 探针确认项**。
- **发现 2（卡片进程受限）**：§1.4 已锁定卡片内**禁用网络 / 文件系统 / 定时器 / @State**；`canOpenLink` 是 SDK 调用，**不能在 `WidgetCard.ets` 里执行**，只能由 `FormAbility` / `EntryAbility`（提供方 / UIAbility 侧）执行后经 `formBindingData` 推给卡片。

### 1.2 结论

普通三方应用**无法「扫描全机自动发现任意新装 App」**。可实现、且恰好等于用户第二句描述的是：**内置常见应用模板 → 每台设备用 `canOpenLink` 逐项探测 → 只有本机装了且声明了该 scheme 的应用才显示 → 装/卸变化在下次刷新被发现**。跨设备差异由「同一份模板 + 各自探测结果」自然产生，无需为每台手机维护清单。

---

## 2. 与既有产品 Spec 的关系（决策增量，不静默冲突）

本 Spec 是 **P7 新增子系统**，对既有决策的处理如下；下表 A/B 两类在实现启动时以「决策变更记录」形式并入主文档 §0.5，本轮不改主文档正文。

| 既有决策 | 处理方式 | 类别 |
|---|---|---|
| §0.6 **A2** 点击即重排 + 定时兜底 | **沿用并扩展**：刷新触发源增加「安装状态重探」，不改变「点击即重排」语义 | 沿用 |
| §0.7 **D5** 本地可替换配置文件 | **沿用**：模板同样作为本地可替换文件，不建服务端 | 沿用 |
| §0.9 **B2′** 全库=已验证条目、不足不凑数 | **新增一层**：引入「模板候选层」，与「已验证层」分层标注（本 Spec §3.4），**不把候选冒充已验证** | 增量（A） |
| §0.6 **A3** 只收录已实测可用条目 | **需登记决策变更**：`canOpenLink` 通过记为「本机安装可用性已实测」，但**不等于原子页落地已实测**；二者显式区分，落地实测仍走 A3 探针 | 变更（B） |
| §4.3 失败不回退、明确提示 + 失效小圆点 | **完全不改**：模板候选被点击失败时原样适用，不新增运行时降级 / 自动换路由 | 不变（硬约束） |
| §2.3 建议区全自动、无手动干预 | **完全不改**：新装/卸载的增删由系统自动完成，无用户手动入口 | 不变（硬约束） |
| §7 运行时不做多路由降级 | **完全不改**：探测只决定「显不显示」，不参与点击时的路由选择 | 不变（硬约束） |
| §1.4 卡片禁用 SDK / 定时器 | **完全不改**：所有探测在提供方 / UIAbility 侧 | 不变 |
| 技术预研 Spec | **不改** | 不变 |

> **诚实边界（必须写进验收口径）**：`canOpenLink` 只证明「该 App 已安装且声明了该 scheme」，**不证明**「付款码 / 扫一扫这类具体子功能一定命中」。因此模板来源条目一律标注 `落地未验证`；被点击失败时仍按 §4.3 明确提示、标失效小圆点，并可在工程侧走 A3 探针把它晋升为「已验证层」。**不宣称"零失效项"**，只宣称"零未安装死链"。

---

## 3. 架构

### 3.1 子系统定位

在 §0.10 的 P1–P6 之外新增 **P7「设备适配与刷新」**，单一职责：**决定「这台设备上、此刻，哪些功能该出现在卡片与内页」，并在安装状态变化时驱动刷新**。它不负责推荐排序（P6/主文档 §6.2）、不负责视觉（P5）、不负责直达执行（P4）。

### 3.2 组件清单

| 文件（拟定） | 单一职责 | SDK 依赖 | Node 单测 |
|---|---|---|---|
| `ets/data/AppTemplateCatalog.ets` | 静态候选模板目录（app → brand / category / 候选子功能 / scheme 占位）；解析与校验 | 无 | ✅ |
| `ets/data/InstalledProbe.ets` | 可注入探测边界：`probe(scheme) → boolean`，生产实现包装 `bundleManager.canOpenLink`；返回本机已安装 appId 集合 | 仅此一处 | ✅（注入假探针） |
| `ets/data/EffectiveCatalog.ets` | 合并「已验证层 + 模板候选层 × 本机已安装」→ 有效 `AtomicFunction[]`；稳定排序、去重、分层标注 | 无 | ✅ |
| `ets/data/CatalogDiff.ets` | 与上次快照比对 → `added / removed / unchanged`；去抖阈值 | 无 | ✅ |
| `ets/data/InstallSnapshotStore.ets` | Preferences 持久化上次「已安装集合 + 探测时刻 + 版本指纹」，抑制抖动 | `@ohos.data.preferences`（边界） | ✅（注入内存 store） |
| `ets/form/RefreshOrchestrator.ets` | 统一组装：`探测 → 有效目录 → diff → 快照 → CardBinding.compose → updateForm`；与 D2 失败态刷新解耦 | `formProvider`（边界） | ✅（纯编排部分） |
| `module.json5` | 新增 `module.querySchemes` 白名单（≤50） | 配置 | — |
| `resources/.../form_config.json` | 调整刷新配置（本 Spec §6.3） | 配置 | — |
| `resources/rawfile/app_templates.json` | 模板数据（D5 可替换） | 数据 | — |

**依赖方向**：`AppTemplateCatalog / EffectiveCatalog / CatalogDiff` 纯逻辑（零 SDK）→ 被 `InstalledProbe / InstallSnapshotStore / RefreshOrchestrator` 组合 → 被 `FormAbility / EntryAbility` 调用。卡片 `WidgetCard.ets` **只消费 `formBindingData`，零改动**。

### 3.3 数据流

```
[app_templates.json / 编译期常量]  （同一份，随 HAP 分发到所有手机）
   │  appName · brand · category · scheme* · 候选子功能 · kind
   ▼
InstalledProbe ── canOpenLink(scheme) ──► 本机「已安装 appId 集合」   ← 每台设备各自算
   │                                              │
   ▼                                              ▼
EffectiveCatalog ◄── capabilities.json（已验证层，A3，仍可 hdc push 替换）
   │   合并 / 过滤「未安装不显示」/ 稳定排序 / 分层标注
   ▼
CatalogDiff ◄── InstallSnapshotStore（上次快照 + 去抖）
   │   added(新装) / removed(卸载) / unchanged
   ▼
RefreshOrchestrator
   ├─ onAddForm / onUpdateForm / onFormEvent        → compose → updateForm
   ├─ EntryAbility 打开 / 返回 / 直达成功           → compose → updateForm（主动刷新）
   └─ setFormNextRefreshTime（仅 D2 失败态 TTL）    → 与安装刷新解耦，互不覆盖
   ▼
formBindingData (frames / suggestions / categories / …)
   ▼
WidgetCard @LocalStorageProp → 嵌套框渲染（key 必须含内容，见本 Spec §5.4）
```

### 3.4 两层目录模型（关键设计）

| 层 | 来源 | 语义 | 显示条件 | 点击失败时 |
|---|---|---|---|---|
| **L1 已验证层** | `capabilities.json`（A3 / D5） | 「原子页已真机实测可直达」 | 恒显示（若其 app 未安装则由 `canOpenLink` 一并过滤） | §4.3 明确提示 + 失效小圆点 |
| **L2 模板候选层** | `app_templates.json`（本 Spec 新增） | 「本机已安装该 App（安装可用性已实测），子功能落地未验证」 | **`canOpenLink(template.scheme) === true` 才显示** | 同 §4.3；工程侧可走 A3 探针晋升到 L1 |

- L2 **不写入** `capabilities.json`，产品空种子 `{items:[]}` 立场**不破坏**。
- L2 条目在 `AtomicFunction` 上以 `source: 'template'` / `confidence` 低值显式标注（沿用 `SOURCE_CONFIDENCE` 既有字段语义，需登记取值）。
- **未安装 → L2 不产生任何条目**，满足用户「不要出现对应图标」的核心诉求。

---

## 4. 模板目录（候选清单，诚实标注）

### 4.1 模板条目结构（字段契约）

```ts
interface AppTemplateEntry {
  id: string;                 // 稳定 id，如 'tpl:alipay'
  appName: string;            // 可读名，供 BrandMark 解析原生标识
  bundleName: string;         // 已知包名；未知则留空并标 kind='unknown'
  category: string;           // 必须 ∈ CATEGORIES（9 类）
  scheme: string;             // ★ 待 Task 0 真机探针回填；回填前为空 → 不参与探测 → 不显示
  kind: 'third-party' | 'system' | 'unknown';
  functions: TemplateFunction[]; // 候选子功能（label + route 占位，落地未验证）
  verifiedByProbe: boolean;   // 是否已完成 A3 落地实测（初始 false）
}
```

**`scheme` 的鸡生蛋问题（明确解法）**：scheme 是 **App 级事实（跨设备一致）**，不是设备级事实。故由 **Task 0 一次性工程探针**在真机上为模板内每个 App 查得并回填进模板文件；**在那之前 `scheme` 为空、该模板不参与 `canOpenLink`、不显示**。跨设备差异仍由每台设备各自的 `canOpenLink` 结果产生，不要求每台手机重跑探针。所有 scheme 汇总进 `module.querySchemes`（≤50）。

### 4.2 常见应用候选清单（按 9 类目；全部 `verifiedByProbe=false`）

沿用 `BrandMark` 已有 25 条品牌，缺品牌者标注「需补标识」。

| 类目 | 候选应用（括号内为候选子功能，均落地未验证） | 标识 |
|---|---|---|
| 支付 | 支付宝（付款码 / 扫一扫 / 转账 / 收款）、微信（扫一扫 / 收付款）、云闪付（付款码）* | 前二已有；云闪付需补 |
| 购物 | 淘宝（购物车 / 订单 / 搜索）、京东（订单 / 购物车）、小红书（搜索 / 发布）、拼多多（订单）* | 前三已有；拼多多需补 |
| 出行 | 高德地图（打车 / 导航 / 公交）、百度地图（路线 / 公交）、12306（车票查询 / 订单）、携程（机票 / 酒店）、滴滴出行（打车）* | 前四已有；滴滴需补 |
| 社交 | 微信（消息 / 朋友圈）、QQ（消息 / 扫一扫）、微博（热搜 / 发布）、抖音（消息 / 搜索） | 已有 |
| 生活 | 美团（外卖 / 团购 / 订单）、天气（预报）、日历（新建日程）、时钟（闹钟 / 计时）、备忘录（新建）、相机（拍照）、电话（拨号）、信息（新建短信）、设置（Wi-Fi / 蓝牙） | 已有；系统应用见本 Spec §4.3 |
| 娱乐 | 抖音（推荐 / 搜索）、哔哩哔哩（动态 / 搜索）、腾讯视频（搜索 / 我的）、网易云音乐（每日推荐 / 搜索）、微博（热搜） | 已有 |
| 健康运动 | 运动健康（步数 / 心率 / 运动记录） | 已有 |
| 工具效率 | 备忘录、日历、时钟、相机、设置、信息 | 已有 |

\* = `BrandMark` 未收录，需补品牌色 / 字形。

### 4.3 系统应用的单独口径

电话 / 信息 / 相机 / 日历 / 时钟 / 设置 / 备忘录 / 天气 / 运动健康等系统应用的入口**未必是 `scheme://` deep link**，可能是 `want` 显式 ability 或 linkFeature。`canOpenLink` 只接受 link 字符串，故：

- 系统应用单列 `kind:'system'`，**探测策略与三方不同**（Task 0 一并查证能否用 linkFeature 形式让 `canOpenLink` 返回真）。
- **Task 0 无法验证的系统应用，一律不进入 L2 显示集合**（宁缺毋滥，符合「减少错误」）。
- 不为凑数编造系统应用 scheme。

### 4.4 `querySchemes` 约束

- 模板内**每个非空 scheme** 必须在 `module.json5` 的 `querySchemes` 声明，否则 `canOpenLink` 抛 `17700056`。
- 总数 ≤50；当前候选约 25 个 App，一 App 一 scheme 时余量充足；若某 App 需多 scheme，需评审是否超限。
- scheme 字符串需匹配 `^[a-zA-Z][0-9a-zA-Z+.-]*`。

### 4.5 诚实边界（重申）

`canOpenLink=true` ⟹ 「App 装了、scheme 声明了」；**⟹̸ 「付款码这一页能打开」**。L2 的全部子功能仍属 A3 未回填范畴。验收口径只承诺 **S5「零未安装死链」**，不承诺「零失效项」。

---

## 5. 探测 / 有效目录 / diff

### 5.1 `InstalledProbe`（唯一 SDK 边界）

- 接口：`interface SchemeProbe { canOpen(scheme: string): boolean; }`，生产实现 = `bundleManager.canOpenLink`。
- 纯逻辑封装：`InstalledProbe.installedIds(templates, probe) → Set<string>`：跳过 `scheme===''`、捕获异常当 `false`、不因单条失败中断整批。
- **不调用 `getBundleInfo`**（权限不可得，本 Spec §1）。

### 5.2 `EffectiveCatalog`

- 输入：L1 已验证条目、L2 模板、`installedIds`、用户配置排除项（若有）。
- 规则：
  1. L2 模板按 `installedIds` 过滤 → 生成候选 `AtomicFunction[]`（`source:'template'`）。
  2. L1 条目若其 app 的 scheme 探测为 `false`，同样过滤（避免"已验证但本机已卸载"的残留）。
  3. 以 `id` 去重（L1 优先，同 id 的 L2 候选被吸收）。
  4. 稳定排序：沿用既有 `WidgetCardData` / `PinyinUtil` 口径，不引入新排序维度。
  5. 产出直接喂给现有 `CardBinding.compose`，**不改动推荐引擎（主文档 §6.2）**。

### 5.3 `CatalogDiff` 与快照

- `InstallSnapshotStore` 持久化：`{installedIds[], probedAt, appVersionFingerprint?, streak: Record<string, number>}`（`streak` 记每个 id 连续一致的探测次数；沿用模型已有的 `appVersionFingerprint` 字段）。
- `diff(prev, next)` → `added`（新装）/ `removed`（卸载）/ `unchanged`；供刷新时决定是否需要 `updateForm`（无变化可跳过，省电省闪）。
- **去抖（取值已定，不留自由参数）**：同一 id 需**连续 2 次**探测结果一致才写入快照并触发增删；即单次 `true↔false` 抖动不改变卡片。`streak` 在结果变化时归 1、一致时 +1、达到 2 才落库。理由：平台周期刷新最快 30 分钟，2 次 ≈ 最长 60 分钟才确认一次装/卸，换取「不闪烁」；即时性由「打开 App 主动刷新」路径补足（本 Spec §6.1）。
- 应用升级（`appVersionFingerprint` 变化）触发**重新探测**，因为 scheme 可能随版本变更（对应主文档 §6.4 既有「版本指纹」机制的运行时落点，仍不改预研 Spec）。

### 5.4 卡片侧渲染约束（本轮已验证的经验）

- `install -r` 不重触发 `onAddForm`；结构变化只能靠 `updateForm` 推新 `formBindingData`。
- `ForEach` 的 key **必须含内容**（本轮已修 `CardBinding` 的 `frame.key` 含 `label + 各 item.id`）。新增 / 删除文件夹框时沿用该规则，否则会复用旧子树、出现「删了还在 / 装了不出」。
- 卡片内不引入 `Grid` / `Scroll`（无 `@form` 支持），沿用现有 `Flex(wrap)` + `Stack` 嵌套框。

---

## 6. 刷新编排

### 6.1 触发源（按可靠性排序）

| 优先级 | 触发 | 时效 | 说明 |
|---|---|---|---|
| 1 | **打开 App / 从内页返回 / 点卡片拉起 UIAbility** | 即时 | 主动 `updateForm`，最可靠的「装完马上变」路径；复用 A2「点击即重排」 |
| 2 | **`onUpdateForm` 平台周期刷新** | ≤30 分钟 | 卡片在桌面静置时的主要兜底 |
| 3 | **`onAddForm` 首次添加** | 一次 | 建立初始快照 |
| 4 | `onFormEvent` / 直达成功后 | 即时 | 既有链路顺带重探 |
| 5（可选补充） | `COMMON_EVENT_PACKAGE_*` 动态订阅 | 仅进程存活期 | **不作主触发**；若实现只作为加速，不依赖它 |
| 6 | `scheduledUpdateTime` 定点 | 每日一次 | 与周期刷新二选一，见本 Spec §6.3 |

> **不承诺**：装完 App 后桌面卡片「秒级」自动变化。用户可打开一次 App 立即生效，否则最迟 30 分钟内生效。此限制源于平台，写入验收口径与报告。

### 6.2 与 D2 失败态刷新解耦

现有 `FormAbility.push()` 会在失败态时 `setFormNextRefreshTime(formId, 1)` 排 1 分钟后清除失败文案。**安装状态刷新不得被该定时器覆盖或相互打架**：

- `RefreshOrchestrator` 组装 `CardBindingData` 时**保留当前 `failure` / `failureAt`**（从现有绑定读取，不重算、不清空）。
- 安装刷新与失败清除共用 `onUpdateForm`，按「先按 TTL 判定失败态，再叠加安装态有效目录」的顺序合成，二者互不覆盖。
- `setFormNextRefreshTime` 仍只服务于失败态 TTL，不为安装刷新额外排定时器（避免刷新风暴）。

### 6.3 `form_config.json` 调整建议（含本 Spec §1.1 发现 1）

- 现状：`updateEnabled:true` + `scheduledUpdateTime:"10:30"` + `updateDuration:1` 三者并存 → 按 SDK 文档**定点优先**，周期刷新可能实际未生效。
- 建议：**保留 `updateEnabled` 与 `updateDuration`（周期），去掉 `scheduledUpdateTime`**，让「定期刷新」真正生效；或二者只留其一并在 Task 0 真机观察 `refreshCount` 确认。
- **列为实现阶段的验证项，不作为本设计稿的既成事实**：需在 Task 0 用 `hidumper -s FormMgr` 观察实际刷新计数后再定稿。

### 6.4 卡片侧约束

所有探测 / 文件读取 / SDK 调用均在 `FormAbility`（提供方）或 `EntryAbility`（UIAbility）进程；`WidgetCard.ets` 维持纯 `@LocalStorageProp` 渲染，零 SDK、零定时器（主文档 §1.4 硬约束）。

---

## 7. 错误处理与稳定性

| 场景 | 行为 |
|---|---|
| `canOpenLink` 抛 `17700056`（scheme 未声明） | 视为 `false`，该模板不显示；**记入工程侧告警**（说明 `querySchemes` 漏配），不崩、不误报空态 |
| `canOpenLink` 抛 `17700055`（link 非法）/ `401` | 视为 `false`，同上；模板文件中把该 scheme 标为待修 |
| 权限异常 / SDK 不可用 | 整批探测降级为「沿用上次快照」，**不清空卡片**（避免一次失败把所有图标抹掉） |
| App 已卸载 | `canOpenLink=false` → 有效目录移除 → 下次刷新图标消失（S3） |
| App 新装 | `canOpenLink=true` → 有效目录新增 → 下次刷新图标出现（S2） |
| 模板候选子功能点击失败 | **完全沿用 §4.3**：明确提示「『X』暂无可用直达入口」+ 失效小圆点；**不回退首页、不试其他路由、不自动换方案** |
| 全部应用都未安装 / 模板全空 | 沿用既有**诚实空态**「添加你常用的功能」，不补假图标（A3 / B2′） |
| 探测抖动 | `InstallSnapshotStore` 去抖（本 Spec §5.3），不闪烁 |
| 配置文件非法 / 解析失败 | 沿用 `CapabilityRepository.parse` 的「返回空数组不崩」口径；L2 同理 |

---

## 8. 验证策略

### 8.1 Task 0 一次性探针（**先证可行，再写实现代码**）

按 §0.6「事件链路先探针实证再定」的既有拍板，实现阶段第一步是**一次性、可丢弃**的真机探针（不写产品代码）：

1. 在 `module.json5` 临时声明 1–2 个已知 scheme → 编译安装 → 调 `canOpenLink` 观察返回值，确认**普通 HAP + `querySchemes` 组合真机确实生效**。
2. 用 `hidumper -s FormMgr` 观察 `refreshCount` / `isCountTimerRefresh`，确认**去掉 `scheduledUpdateTime` 后周期刷新真的在跑**（本 Spec §1.1 发现 1）。
3. 为模板内每个候选 App 查得真实 scheme（工程侧查证，不编造）；无法查得的条目保持 `scheme=''` 不显示。
4. 记录系统应用（`kind:'system'`）是否可用 link 形式探测；不能者排除出 L2。

> 若 ① 结论为「`canOpenLink` 在本机不可用」→ **如实报告并回到工程层换方案**（例如退回「仅 A3 已验证条目 + 用户自行替换配置文件」），**不在运行时偷偷兜底**。这符合「失败不要回退，直接报告给我，如果不支持我们应该换方案」的既有立场。

### 8.2 Node 单测（纯逻辑，TDD RED→GREEN）

- `AppTemplateCatalog`：解析 / 校验 / 类目合法 / 空 scheme 不参与探测。
- `InstalledProbe`：注入假探针 → 已安装集合正确；单条异常不中断；空 scheme 跳过。
- `EffectiveCatalog`：L1+L2 合并、未安装过滤、去重（L1 优先）、稳定排序、分层标注。
- `CatalogDiff`：added / removed / unchanged；去抖；升级触发重探。
- 回归：既有 94 tests 全绿；`CardBinding` 的 content-derived key 在增删框时仍不复用旧子树。

### 8.3 真机验收场景

| 场景 | 期望 |
|---|---|
| 换一台只装少量 App 的手机 | 卡片只显示该机装了的应用（S1） |
| 装一个模板内 App | 打开一次 App 立即 / 或 ≤30 分钟后出现（S2） |
| 卸载该 App | 下次刷新消失（S3） |
| 断网 / 探测异常 | 卡片保持上次有效目录，不空白、不崩（S4） |
| 点一个 L2 候选失败 | §4.3 提示 + 小圆点，无回退（S6） |

### 8.4 明确不承诺

- 秒级即时刷新；任意未列入模板的新装 App 被自动发现；L2 子功能「一定命中」；`getBundleInfo` 全机枚举；云 / 服务端下发。

---

## 9. 风险登记

| # | 风险 | 影响 | 缓解 |
|---|---|---|---|
| R1 | `canOpenLink` + `querySchemes` 真机不生效 | 整套设备适配失效 | Task 0 探针先行；不生效则如实报告并换工程方案，不运行时兜底 |
| R2 | scheme 需 ≤50，模板扩展受限 | 常见应用覆盖不全 | 一 App 一 scheme；超限评审；优先高频应用 |
| R3 | `canOpenLink` 只证 App 装了，不证子功能落地 | 仍可能存在失效项 | L1/L2 分层标注、沿用 §4.3、A3 探针晋升；不宣称零失效 |
| R4 | 周期刷新被定点配置抢占 | 「定期刷新」名存实亡 | 本 Spec §6.3 调整 + Task 0 观察 `refreshCount` |
| R5 | 探测抖动导致图标闪烁 | 体验差 | 快照去抖（本 Spec §5.3） |
| R6 | 与 D2 失败态刷新互相覆盖 | 失败文案消失 / 刷新风暴 | 本 Spec §6.2 解耦，共用合成顺序 |
| R7 | 模板预置被认为与 A3「只收实测」冲突 | 产品立场争议 | 本 Spec §2 明确登记为「决策变更」，分层标注、不改空种子 |
| R8 | 系统应用无 link scheme | 覆盖缺口 | `kind:'system'` 单列，Task 0 无法验证者不显示 |
| R9 | 上架合规（若未来上架） | 模板预置三方 scheme 的合规风险 | 沿用「内部自用 / 真机演示」定位（§0.7），本期不评估上架 |

---

## 附录 A：本机 SDK 证据索引

| # | 文件 | 位置 / 内容 |
|---|---|---|
| A-1 | `ets/api/@ohos.bundle.bundleManager.d.ts` | 全文件无 `getAllBundleInfo` / `getAllApplicationInfo` 导出；仅 `getBundleInfo` / `getBundleInfoForSelf` / `getBundleNameByUid` |
| A-2 | 同上 | `getBundleInfo` 注释：「The application requires to be a system application when requesting the permission of ohos.permission.GET_BUNDLE_INFO」；`@permission GET_BUNDLE_INFO_PRIVILEGED or GET_BUNDLE_INFO`；`201 Permission denied` |
| A-3 | 同上 | `function canOpenLink(link: string): boolean;` `@atomicservice` `@since 12` `@syscap SystemCapability.BundleManager.BundleFramework.Core`；`17700056 scheme not in querySchemes` |
| A-4 | `toolchains/modulecheck/module.json` | `querySchemes`: array / `maxItems: 50` / items `^[a-zA-Z][0-9a-zA-Z+.-]*` / `maxLength: 128` |
| A-5 | `ets/api/@ohos.commonEventManager.d.ts` | `COMMON_EVENT_PACKAGE_ADDED / REMOVED / REPLACED / FULLY_REMOVED / CHANGED`（since 9） |
| A-6 | `toolchains/modulecheck/forms.json` | `updateDuration` 注释：「unit is 30 minutes… maximum frequency … every 30 minutes. You can select either refresh or refresh at a fixed point. **If both are configured, the card is refreshed at a scheduled time.**」 |
| A-7 | `ets/api/@ohos.app.form.formProvider.d.ts` | `updateForm` / `setFormNextRefreshTime`（工程已在 `FormAbility.push` / `EntryAbility.pushCardResult` 使用） |
| A-8 | 真机 `hidumper -s FormMgr -a '-i 637944382'`（2026-11-08） | `updateDuration [1800000]`、`updateAtHour [10]`、`updateAtMin [30]`、`isCountTimerRefresh [0]`、`refreshCount [3]`、`formStatus [RENDERED]` |
| A-9 | 真机 `hidumper -s FormMgr -a '-r'`（2026-11-08） | `FunctionPanelCard` / `bundleName [com.example.minimal]` / `specification [4]`（4×4） |

## 附录 B：待 Task 0 回填的 scheme 清单（占位，全部 unverified）

> **本表刻意留空具体 scheme 字符串**。任何 concrete scheme 必须由本 Spec §8.1 Task 0 真机查证后回填；**禁止凭空编造并当作已验证路由**。回填前对应模板 `scheme=''`，不参与 `canOpenLink`、不显示。

| 模板 id（拟定） | appName | category | scheme | 状态 |
|---|---|---|---|---|
| `tpl:alipay` | 支付宝 | 支付 | `''` | 待 Task 0 |
| `tpl:wechat` | 微信 | 支付 / 社交 | `''` | 待 Task 0 |
| `tpl:taobao` | 淘宝 | 购物 | `''` | 待 Task 0 |
| `tpl:jd` | 京东 | 购物 | `''` | 待 Task 0 |
| `tpl:amap` | 高德地图 | 出行 | `''` | 待 Task 0 |
| `tpl:baidumap` | 百度地图 | 出行 | `''` | 待 Task 0 |
| `tpl:meituan` | 美团 | 生活 | `''` | 待 Task 0 |
| `tpl:12306` | 中国铁路 12306 | 出行 | `''` | 待 Task 0 |
| `tpl:douyin` | 抖音 | 娱乐 | `''` | 待 Task 0 |
| …（其余按本 Spec §4.2 清单展开） | | | `''` | 待 Task 0 |
| `tpl:phone` / `tpl:camera` / `tpl:settings` … | 系统应用 | 生活 / 工具效率 | `''` | `kind:'system'`，Task 0 无法验证则不显示 |

---

> **本 Spec 的边界**：它是 P7 子系统的**设计定稿**，不含实现步骤与代码。按既定流程，需用户过目确认后，才进入 `writing-plans` 写实现计划，再进入 TDD 开发。技术预研 Spec 与既有产品 Spec 正文本轮均未改动。
