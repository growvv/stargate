# 能力面板形态 A（本设备可用能力 + 自有功能）与 L0 过滤 设计 Spec

> 日期：2026-11-08
> 状态：设计稿（用户已拍板定位 A + EffectiveCatalog 加 L0 过滤；本稿为书面 Spec，实现前仍需写实现计划）
> 依据：`docs/research/capability-shape-convergence-2026-11-08.md`（收敛稿）、`A3-FINDINGS.md`、`A3-ROUND3-FINDINGS.md` §3.5/§3.6、OpenHarmony `start-intent-panel.md`、本地 SDK `application/UIAbilityContext.d.ts:1923/1962`。
> 关联：产品 Spec `2026-11-07-harmony-atomic-function-panel-product-design.md` §7（单路由 / 失败即报告 / 无运行时降级）、P7 Spec `2026-11-08-harmony-atomic-function-panel-install-aware-sync-design.md`（模板与安装感知，本稿改变其「模板可进卡片」语义）。
> 本稿**不修改**上述既有 Spec 正文；它是新增的形态增补 Spec。技术预研 Spec 正文不变。

---

## 1. 目标与非目标

### 1.1 目标

1. 把产品定位调整为「**本设备可用能力 + 自有功能**」：卡片来源由我们自己决定，不再依赖厂商开放私有子页。
2. 让「**每个 App 一个独立点击入口、参数预先填好**」成为一等卡片形态（S2 显式带参），真机已验证的 1 条落地为产品数据。
3. 接入 `startAbilityByType` 的 9 类官方垂类场景作为**独立入口**（S3），不伪装成一键直达。
4. **EffectiveCatalog 加 L0 过滤**：只有「真机截图确认落点」的条目能进可直接点击目录；未验证的模板候选一律不得生成卡片，也不得按 appName 隐藏已验证条目。
5. 保持产品 Spec §7 全部硬约束：单条 `route`、显式 `bundleName`、失败即 `NO_AVAILABLE_ENTRY`、运行时不降级、不回退首页。

### 1.2 非目标（明确不做）

- 不做「微信扫一扫 / 支付宝付款码 / 高德打车」等私有子页：A3 两轮 + 286 包 harvest 已证无公开 URI，不编造。
- 不枚举元服务 / 服务卡片：`formHost` 全 namespace `@systemapi` + `GET_BUNDLE_INFO_PRIVILEGED`，普通 App 用不了。
- 不新增运行时多路由遍历、不新增 `home` kind、不新增首页兜底。
- 不把 L1/L2/L3 候选自动晋级；不承诺卡片数量几十条。
- 不处理 AGC 401 真包签名（用户明确「后续签名一下就行了」）。
- 不修 `explorer` 空白页独立缺陷（另案）。
- 不执行 P7 实现计划（模板/定时刷新的其它部分保持现状）。

---

## 2. 定位 A 的准确定义

**卡片 = 本设备上「已被证据确认可到达的能力入口」+「我们自己 App 内的功能入口」+「用户自己登记的快捷方式」+「系统公开的垂类/标准入口」。**

| 层 | 名称 | 谁能进卡片 | 判定者 |
|---|---|---|---|
| L0 | 生产可用 | 真机截图确认落点 | 人工审核 |
| L0+ | 显式带参已验证 | 真机截图确认带参落点 | 人工审核 |
| L1 | 官方垂类场景 | 官方映射契约 + 真机面板/落点截图 | 人工审核 |
| L2 | 场景×App 矩阵 | 逐 App 真机截图 | 人工审核 |
| L3 | 自有页 / 系统入口 / 用户自定义 | 自有页真机验证；用户自定义由用户自担 | 人工审核 / 用户 |

`capabilities.json`（HAP 内种子 + D5 外部可替换文件）是**唯一可直接点击目录**。`discovery-candidates.json` 与 `app_templates.json` 是候选面，**永远不直接生成卡片**。

---

## 3. 卡片模型（沿用 `AtomicFunction`，两处最小扩展）

### 3.1 数据契约

```
RouteKind = 'want' | 'deeplink' | 'applinking' | 'shortcut-param' | 'vertical'
Route.parameters?: Record<string, string | number | boolean>
AtomicFunction = { id, label, appName, bundleName, category, route, source, confidence, appVersionFingerprint? }
```

- **扩展 1**：`RouteKind` 增加 `'vertical'`（S3）。
- **扩展 2**：`Route.parameters` 值类型从 `string` 放宽为 `string | number | boolean`。理由：A3 真机验证的 `destinationLatitude: 32.060844` 是真浮点；CLI `--pi` 只能传整数，0/0 坐标算不出路线。ArkTS `Want.parameters` 接受 `Record<string, Object>`，本类型是可序列化的子集。
- 其余字段不变；`route` 仍只有一条，无 `routes[]`、无 `home`。

### 3.2 六种来源 → 单条 route

| # | 来源 | route 形状 | 启动方式 |
|---|---|---|---|
| S1 | 已验证私有直达 | `{kind:'deeplink'\|'applinking', uri}` | `startAbility(Want)` |
| S2 | 场景×App 显式带参 | `{kind:'deeplink', uri, parameters}` | `startAbility(Want)` |
| S3 | 官方垂类面板 | `{kind:'vertical', parameters:{verticalType, sceneType, ...业务参数}}` | `startAbilityByType(type, wantParam, cb, callback)` |
| S4 | 系统公开入口 | `{kind:'want', uri?, parameters:{action, ...}}` | `startAbility(Want)` |
| S5 | 自有功能页 | `{kind:'shortcut-param', abilityName:'EntryAbility', moduleName:'entry', parameters:{page}}` | `startAbility(Want)` |
| S6 | 用户自定义 | 同 S1/S2 形状 | `startAbility(Want)` |

`verticalType` / `sceneType` 从 `parameters` 取出后作为 `startAbilityByType` 的 type 与 wantParam 的 `sceneType`；其余 `parameters` 原样作为业务参数传入。`buildWant()` 对 `vertical` **不构造 Want**、不调用 `startAbility`。

### 3.3 `startAbilityByType` 契约（本地 SDK 核对）

`application/UIAbilityContext.d.ts:1923`（callback 版，`@since 11`）与 `:1962`（Promise 版，`@since 12`）：

```
startAbilityByType(type: string, wantParam: Record<string, Object>,
  abilityStartCallback: AbilityStartCallback, callback: AsyncCallback<void>): void
```

- 非 systemapi、无权限声明、`@atomicservice`、仅要求前台调用。
- `AbilityStartCallback` = `{ onError(code,name,message): void; onResult?(parameter): void }`（`application/AbilityStartCallback.d.ts`）。
- 本机 `compatibleSdkVersion 5.0.0(12)` 满足 API 11+；采用 **callback 版**（API 11），与 A3 spike 已验证的调用形状一致。
- 系统按 `type + sceneType` 匹配各 App 声明的 `linkFeature`，弹垂类选择面板；选中后系统把对应 URI 放进 `want.uri`、业务参数放进 `want.parameters`。**这一步是系统行为，不是我们的降级路径。**

### 3.4 失败语义（不加新 reason）

`vertical` 分支失败（callback err / `onError` / 抛异常）仍返回 `ok=false, reason='NO_AVAILABLE_ENTRY'`，UI 显示「『X』暂无可用直达入口」。不重试、不改用 `startAbility`、不打开首页。

---

## 4. L0 过滤（用户拍板项）

### 4.1 定义

**L0 条目 = `source` 属于 `{ 'linkFeature', 'scheme', 'shortcut', 'manual' }` 且 `confidence >= 0.85` 的 `AtomicFunction`。**

- `template` (0.5) / `rea` (0.6) / `injection` (0.2) 一律**非 L0**。
- `manual`（用户自定义，1.0）属 L0 但须在 UI 明示「用户登记、未验证」，由用户自担。
- 判定放在 `AtomicFunction.isL0(fn)` 纯函数，供 `EffectiveCatalog` 与测试共用，不散落魔数。

### 4.2 `EffectiveCatalog` 行为变更

现状（`entry/src/main/ets/data/EffectiveCatalog.ets`）：把已安装模板候选以 `source:'template', confidence:0.5` 合并进 `l1` 生成卡片，并按 `appName` 从 `l1` 里剔除同名条目。

变更后：

1. `EffectiveCatalog.build(l1, templates, installedIds)` 的**返回集合只包含 `l1` 中的 L0 条目**；
2. `templates` 与 `installedIds` **仍参与** `InstallSnapshotStore` / `CatalogDiff` 的安装快照与去重逻辑（P7 的安装感知不废），但**不再向结果注入任何 `template` 条目**；
3. **取消按 appName 隐藏 L0 条目**的行为 —— 已验证条目不因「同名模板存在但未安装」而消失；
4. 结果仍按 `id` 排序，保持 `RefreshOrchestrator.resolve()` 的 `effective` / `effectiveCount` / `CardBinding` 契约不变。

`RefreshOrchestrator` 的探针、双次确认、快照持久化全部保留；只是 `effective` 变干净。`RefreshInput` 结构不变。

### 4.3 兼容性

- `AppTemplateCatalog` 本身不改：它仍是候选目录，供「能力探索」页与安装感知使用。
- `capabilities.json` 现有 4 条 `source` 为 `linkFeature`/`scheme`、`confidence` 0.95/0.85，全部是 L0，过滤后不丢。
- `CapabilityRepository.parse()` 继续校验 kind/类目/confidence；新增 `'vertical'` 需同步加入其 `ROUTE_KINDS` 与 `AppTemplateCatalog.ROUTE_KINDS`（后者仅影响模板文件解析，不产生卡片）。

---

## 5. 首批卡片清单（本 Spec 批准可落地的全部数据）

### 5.1 保留（4 条 L0，已在 `capabilities.json`）

| id | 卡片 | App | uri | source / confidence |
|---|---|---|---|---|
| `real-amap-route` | 路线规划 | 高德地图 | `systemnav://routeplan` | linkFeature / 0.95 |
| `real-jd-storage` | 存储空间 | 京东 | `storage://developer.huawei.com/clearcache` | linkFeature / 0.95 |
| `real-weibo-storage` | 存储空间 | 微博 | `sinaweibo://settings/cache` | linkFeature / 0.95 |
| `real-quark-qianwen` | 千问助手 | 夸克浏览器 | `https://m.sm.cn/` | scheme / 0.85 |

### 5.2 新增（1 条 L0+，S2 显式带参）

```
id:            explicit-amap-routeplan
label:         路线规划·带目的地
appName:       高德地图
bundleName:    com.amap.hmapp
category:      出行
source:        linkFeature
confidence:    0.95
route:
  kind:        deeplink
  uri:         systemnav://routeplan
  parameters:
    sceneType:            1
    destinationLatitude:  32.060844
    destinationLongitude: 118.78315
    destinationName:      测试地点
    vehicleType:          0
```

证据：`evidence/explicit-amap.png` —— 从 `com.example.minimal` 一次点击直达完整路线结果页（我的位置→测试地点、10小时32分 / 1010公里 / ¥460 / 3 方案 / 开始导航），状态栏「◀ 功能面板」。

**与 `real-amap-route` 并列保留**（不合并、不替换）：前者是空输入页、后者是带目的地结果页，两张卡语义不同；实现期不擅自改交互。

### 5.3 新增（9 条 L1 垂类入口骨架，S3）

| id | label | type | sceneType | 真机状态 |
|---|---|---|---|---|
| `vertical-nav-route` | 路线规划·选应用 | navigation | 1 | ✅ 面板 + 落点已验 |
| `vertical-nav-navi` | 导航·选应用 | navigation | 2 | ✅ 面板已验 |
| `vertical-nav-place` | 地点搜索·选应用 | navigation | 3 | ✅ 面板已验 |
| `vertical-mail-compose` | 写邮件·选应用 | mail | 1 | ✅ 面板已验 |
| `vertical-fin-transfer` | 转账·选应用 | finance | 1 | 待验（官方映射） |
| `vertical-fin-repay` | 信用卡还款·选应用 | finance | 2 | 待验 |
| `vertical-flight-no` | 按航班号查询·选应用 | flight | 1 | 待验 |
| `vertical-flight-loc` | 按起降地查询·选应用 | flight | 2 | 待验 |
| `vertical-express` | 查快递·选应用 | express | 1 | 待验 |

- `source: 'manual'`、`confidence: 1.0`（系统契约，非第三方声明；用 `manual` 而非 `scheme` 以免与「已截图落点」混淆）。
- `bundleName: 'com.stargate.functionpanel'`（形态 A 卡片归属本应用；由 `startAbilityByType` 系统匹配目标 App，本字段**不**作为 Want 的 `bundleName` 使用，vertical 分支不构造 Want）；`appName: '系统能力'`。现有 `CapabilityRepository.parse()` 要求 `bundleName` 非空，故不填 `''`。
- 每条 `parameters` **只写已由官方文档确认的字段**；navigation 三条带 A3 spike 已验证的 `destinationLatitude/destinationLongitude/destinationName`，其余五条**不预填臆测业务参数**，仅 `verticalType` + `sceneType`。
- UI 必须标明「会弹出系统应用选择」（`WidgetCardData` 增加可选 `pickerHint`，不改动现有卡片视觉主结构）。
- **五条「待验」仍进首批**：它们是官方公开契约决定的入口，不是第三方私有 scheme；但必须在 README / 候选面标注「官方映射，真机落点待验」，且不得计入「已验证直达」宣传口径。

### 5.4 不进首批

百度 / 花瓣的显式带参卡（确认框 / 隐私协议未稳住）、S4 系统公开入口（0 条已验）、S5 自有页（`explorer` 空白）、S6 用户自定义编辑器、L2 矩阵其余格、`discovery-candidates.json` 的 48 个候选。它们留在候选面，逐格真机验证后再按同一晋级规则加。

---

## 6. 失败与边界

1. **单路由**：`vertical` 也是一条 `route`；`parameters` 不是第二条路由。
2. **显式**：S1/S2/S4/S5/S6 的 Want 必须带 `bundleName`；S3 的 bundleName 为空是系统匹配语义，不属「裸 uri 隐式启动」。
3. **失败即报告**：所有分支统一 `NO_AVAILABLE_ENTRY`；首次系统确认框 / 隐私协议 / 登录态是预期阻挡，不伪装成功。
4. **参数键名逐 App 确认**：禁止把高德参数表复制给百度 / 花瓣；未验证的键名不写进数据。
5. **数值精度**：`parameters` 里的浮点必须原样传入，不字符串化、不截断。
6. **证据分级**：`capabilities.json` 只收 L0 / L0+ / L1 系统契约；L2/L3 候选不混入。
7. **安装感知（P7）**：`canOpenLink` / 安装快照只证明「装了 + 声明了」，不证明这页能打开；晋级条件仍是截图确认。本 Spec 让模板候选不再生成卡片，但不删除 P7 的安装快照与 diff 逻辑。
8. **真包签名**：AGC 401 仍阻塞，按用户指示不碰；本 Spec 的验收以纯逻辑测试 + 现有对照包机制为准。

---

## 7. 测试策略（TDD，先红后绿）

| 层 | 测试 | 断言 |
|---|---|---|
| 模型 | `AtomicFunction.isL0` | linkFeature/0.95 ✅；template/0.5 ❌；rea/0.6 ❌；manual/1.0 ✅；缺 confidence ❌ |
| 模型 | 浮点参数 | `32.060844` 保持 number、不字符串化 |
| 解析 | `CapabilityRepository.parse` | 接受 `vertical` kind；仍拒绝 `home` / 非法类目 / 非法 confidence |
| 解析 | `AppTemplateCatalog.parse` | `vertical` kind 可解析（不产生卡片） |
| 目录 | `EffectiveCatalog.build` | 已安装模板**不**注入卡片；L0 条目不因同名模板消失；非 L0 的 l1 条目被过滤；结果按 id 排序 |
| 编排 | `RefreshOrchestrator.resolve` | 模板经过双次确认后 `effectiveCount` 仍为 0；L0 条目数稳定；snapshot/diff 行为不变 |
| 分发 | `LaunchDispatcher.launch` | `vertical` 走 `StartAbilityByTypeFn`，**不**调用 `starter`；`type`/`wantParam` 正确；失败返回 `NO_AVAILABLE_ENTRY` 且不降级 |
| 分发 | 参数透传 | S2 的 `parameters` 原样进 `want.parameters`（含浮点）；S1 无参数时不加 `parameters` |
| 数据 | 种子 JSON | 5 条 S1/S2 + 9 条 S3 全部可 parse、类目合法、L0 判定符合预期 |
| 回归 | 全量 `node test/run.mjs` | 0 fail |

---

## 8. 验收标准

1. `node test/run.mjs` 全绿，且新增测试均先红后绿、有输出证据。
2. `capabilities.json` 为 14 条（4 + 1 + 9），`CapabilityRepository.parse()` 全部接受。
3. `EffectiveCatalog.build()` 对「已安装模板 + L0 条目」的输出只含 L0 条目，`effectiveCount` 不再随模板安装数变化。
4. `LaunchDispatcher` 的 `vertical` 分支不调用 `startAbility`，失败不回退。
5. 未改既有 Spec 正文、未改技术预研 Spec、未重建/重装 HAP、未碰 AGC 签名、无 git/commit/push。
6. 证据与边界写进 `progress.md` 台账；`capabilities.README.md` 同步更新（说明 L0 过滤 + 垂类入口 + 待验标记）。

---

## 9. 开放项（不阻塞本 Spec，记录供后续）

- `explorer` 页纯白空白（`main_pages.json` 未注册 `CapabilityExplorerPage`）—— 独立缺陷，另案。
- 百度 / 花瓣显式带参落点：需要用户过一次确认框 / 隐私协议后补截图。
- L1 五条「待验」垂类的真机落点截图。
- 真包 `com.stargate.functionpanel` 签名装机（用户另行安排）。
- P7 实现计划其余任务（模板 / 定时刷新）仍待执行，本 Spec 只改变模板的「能否进卡片」语义。
