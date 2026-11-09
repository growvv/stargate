# 能力清单与卡片模型收敛（A3 round-3 结论版，供评审）

- 日期：2026-11-08
- 来源：用户「好，继续」＝对上一轮收尾提出「按这个结论收敛一版**能力清单 + 卡片模型**给你过目」的确认。
- 性质：**设计评审稿（写文档，不改产品代码、不改任何 Spec 正文）**。产品形态变更涉及定位调整，未经书面 Spec/plan 批准不落地实现。
- 证据基线：`A3-FINDINGS.md`（第 1/2 轮）、`A3-ROUND3-FINDINGS.md` §3.5/§3.6、`linkfeature-all.json`（286 包 / 1425 URI / 213 linkFeature / 77 条去重声明）、`evidence/explicit-*.png`、`evidence/typelaunch-*.png`。
- 真机：`5KPBB25927200695`（HUAWEI MatePad Mini / HarmonyOS 7.0.0.111 SP16）。

---

## 1. 一句话结论

平台不向普通第三方 App 开放「枚举并直达任意 App 任意私有子页」，所以「微信扫一扫 / 支付宝付款码」永远做不到；但**「每个 App 一个独立点击入口、参数预先填好」已用显式 Want 真机验证成立**。把卡片来源收敛成「已验证单路由 + 场景×App 显式带参 + 官方垂类面板 + 系统公开入口 + 自有功能页 + 用户自定义」，数量由我们自己决定，而不是等厂商施舍。

---

## 2. 卡片模型（沿用现有结构，仅需两处小扩展）

现有契约 `entry/src/main/ets/model/AtomicFunction.ets` 与 `LaunchDispatcher.buildWant()` 已经覆盖新形态的**大部分**：S1/S2/S4/S5/S6 只需填数据，**不需要新机制、不需要新 RouteKind**；**S3 例外，需要一个新分支**（见 §2.0）：

```
AtomicFunction {
  id, label, appName, bundleName, category,
  route: { kind, uri?, parameters?, abilityName?, moduleName? },
  source, confidence, appVersionFingerprint?
}
```

六种来源统一映射成一条 `route`（严格保持「单条最可靠路由、无 routes[]、无运行时降级」）：

| # | 来源 | route 形状 | 点击行为 | 证据门槛 |
|---|---|---|---|---|
| S1 | 已验证私有直达 | `{kind:'deeplink'\|'applinking', uri}` | 显式 Want 直达原子子页 | 已截图确认（4 条） |
| **S2** | **场景×App 显式带参** | `{kind:'deeplink', uri, parameters}` | **显式 Want 一次点击到带参功能页** | **每台目标 App 各自截图确认** |
| S3 | 官方垂类面板 | `{kind:'vertical', parameters:{verticalType,sceneType,...}}` | `startAbilityByType` 弹系统选择面板 | 系统契约 + 面板/落点截图 |
| S4 | 系统公开入口 | `{kind:'want', uri?, parameters:{action:'ohos.want.action.appdetail', ...}}` | 标准系统能力（应用详情等），**不降级到首页** | 逐个真机验证 |
| S5 | 自有功能页 | `{kind:'shortcut-param', abilityName:'EntryAbility', moduleName:'entry', parameters:{page:'all'\|'config'\|'category'}}` | 100% 可控，进自己 App 的功能页 | 3 页已验、explorer 空白待修 |
| S6 | 用户自定义快捷方式 | 用户填 `{bundleName, uri, parameters}`，落到 S1/S2 同一形状 | 同 S2 | 用户自担；UI 明示未验证 |

**S2 是本轮新增、也是数量主要来源**：与 S1 同形，只多一个 `parameters`，`LaunchDispatcher` 现有分支 `if (route.parameters) want['parameters'] = route.parameters` 已经会带上。

### 2.0 S3 需要的单点改动（实现期，非本稿动作）

`startAbilityByType` 不是 `startAbility(want)`，现有 `LaunchDispatcher.launch()` 的 `starter(want)` 注入点接不住它。实现期需要：

1. `RouteKind` 增加 `'vertical'`，`CapabilityRepository.ROUTE_KINDS` 同步放行；
2. `LaunchDispatcher` 增加一条 `vertical` 分支，通过新增的 `StartAbilityByTypeFn` 注入点调用 `UIAbilityContext.startAbilityByType(type, wantParam, callback, abilityStartCallback)`；
3. 该分支**不构造 Want**、不回退 `startAbility`、失败仍固定返回 `NO_AVAILABLE_ENTRY`；系统选择面板由系统托管，不是我们的降级路径；
4. 先写失败单测钉住「vertical 卡片不会误走 startAbility 退化成首页」。

这是**一个枚举值 + 一个分支 + 一个注入点**，仍不属于「新机制」，但必须写清，否则实现者会漏。

### 2.1 一个必须先改的小缺口（属实现期，非本稿动作）

`Route.parameters` 现声明为 `Record<string, string>`，而真机验证的路线规划参数是真浮点 `32.060844 / 118.78315`、`sceneType: 1`、`vehicleType: 0`。CLI `--pi` 只能传整数，实测 0/0 坐标算不出路线（停在输入页）。因此实现期需要把参数值类型放宽为 `Record<string, string | number | boolean>`（或等价 ArkTS 可序列化类型），并补一条单测钉住「浮点经纬度不被字符串化、不丢精度」。**这是类型契约修正，不是新机制。**

### 2.2 参数键名必须逐 App 确认，清单里不预填臆测值

高德 `systemnav://routeplan` 已验证可用 `destinationLatitude/destinationLongitude/destinationName/sceneType/vehicleType`。百度、花瓣各自声明的 uri 不同（`baidumap://map` / `maps://routes`），其参数键名**未验证**，本清单**不写死**；每格进 `capabilities.json` 前必须单独真机截图。禁止把高德参数表复制给别家。

---

## 3. 能力清单（收敛后的候选面，分级、不虚报）

### 3.1 L0 · 生产可用（4 条，已面板 E2E + 截图确认）

| id | 卡片 | App / bundle | uri | 落点 |
|---|---|---|---|---|
| `real-amap-route` | 路线规划 | 高德地图 / `com.amap.hmapp` | `systemnav://routeplan` | 路线规划原子子页 |
| `real-jd-storage` | 存储空间 | 京东 / `com.jd.hm.mall` | `storage://developer.huawei.com/clearcache` | 存储空间子页 |
| `real-weibo-storage` | 存储空间 | 微博 / `com.sina.weibo.stage` | `sinaweibo://settings/cache` | 存储空间子页 |
| `real-quark-qianwen` | 千问助手 | 夸克浏览器 / `com.quark.ohosbrowser` | `https://m.sm.cn/` | 千问 AI 助手页（置信度 0.85） |

### 3.2 L0+ · 显式带参已验证（1 条，本轮新增，spike 未进产品）

| id（建议） | 卡片 | App / bundle | uri | parameters | 落点证据 |
|---|---|---|---|---|---|
| `explicit-amap-routeplan` | 路线规划·带目的地 | 高德地图 / `com.amap.hmapp` | `systemnav://routeplan` | `destinationLatitude:32.060844, destinationLongitude:118.78315, destinationName:'测试地点', sceneType:1, vehicleType:0` | `evidence/explicit-amap.png`：◀ 功能面板 → 完整路线结果页（10小时32分 / 1010公里 / ¥460 / 3 方案 / 开始导航） |

> 与 `real-amap-route` 同 uri，差别是「带参直达结果页」vs「空输入页」。实现期是合并成一个带默认参数的卡片，还是并列两卡，属产品交互取舍，等评审意见。

### 3.3 L1 · 官方垂类场景（9 类，系统维护、天然按已装/已接入筛选）

`startAbilityByType` 的映射（OpenHarmony `start-intent-panel.md` + 各垂类文档；API 11+、非 systemapi、无权限、仅要求前台）：

| type | sceneType | linkFeature | 真机已见 |
|---|---|---|---|
| navigation | 1 | RoutePlan | ✅ 弹出「地图 / 高德地图 / 百度地图」，选高德落到带参结果页 |
| navigation | 2 | Navigation | ✅ 弹 3 家地图 |
| navigation | 3 | PlaceSearch | ✅ 弹 3 家地图 |
| mail | 1 | ComposeMail | ✅ 弹「选择邮件发送方式 / 电子邮件」 |
| finance | 1 | Transfer | 待验 |
| finance | 2 | CreditCardRepayment | 待验 |
| flight | 1 | QueryByFlightNo | 待验 |
| flight | 2 | QueryByLocation | 待验 |
| express | 1 | QueryExpress | 待验 |

**定位**：用户没明确偏好时用（系统自动筛已接入 App）；有明确 App 偏好时走 S2。弹一次系统选择框是它和一键直达的差异，如实标在 UI，不伪装成直达。

### 3.4 L2 · 场景×App 显式带参矩阵（数量由我们决定，逐格验证）

从 `linkfeature-all.json` 的 77 条去重声明里，只有 3 个标准意图有多个 App 声明、可作为「按设备已装 App 铺开」的候选字段：

| 场景 | 声明 App（bundle / 官方 uri） | 当前验证状态 |
|---|---|---|
| 路线规划 RoutePlan | 高德 `com.amap.hmapp` / `systemnav://routeplan`；百度 `com.baidu.hmmap` / `baidumap://map`；花瓣地图 `com.huawei.hmos.maps.app` / `maps://routes` | 高德 ✅；百度 ⏸ 首次系统确认框未稳定捕获落点；花瓣 ❌ 首次隐私协议挡住 |
| 导航 Navigation | 高德 `systemnav://navigation`；百度 `baidumap://map`；花瓣 `maps://navigation` | 三者裸 URI 均落首页；带参未验，不得计入 |
| 地点搜索 PlaceSearch | 高德 `systemnav://poisearch`；百度 `baidumap://map`；花瓣 `maps://textSearch`、`petalmaps://textSearch` | 高德裸 URI 落首页；带参未验 |

另外 `AppStorageMgmt` 有 20 个 App 声明、`AppNotificationMgmt` 3 个、`ComposeMail` 1 个，但第 3 轮 probe8 已证明：**共用同一 `storage://developer.huawei.com/clearcache` 的 4 个 App 里只有京东真直达**，其余全是「暂无可用打开方式 / 隐私弹窗 / 首页」。所以**不能按声明数铺卡片**，只能按「逐 App 截图确认」铺。

> 这就是「数量可控」的真实含义：矩阵格数上限由官方声明决定，实际可用数由真机证据决定。早期可能仍是十几条，不承诺几十条。

### 3.5 L3 · 系统公开入口 / 自有页 / 用户自定义（补量、语义诚实）

- **S4 系统公开入口**：应用详情（`ohos.want.action.appdetail`）、权限/通知设置等标准 action。第 1 轮 probe4 已证明**系统 App 私有 scheme 不接受外部 `-U`**，但标准 action 是公开契约，需逐个真机验证后再进清单。目前 0 条已验证，不虚报。
- **S5 自有功能页**：`all` / `config` / `category` 三页已真机验证（`evidence/selfpage-results.json`）；`explorer` 纯白空白是独立缺陷（`main_pages.json` 未注册 `CapabilityExplorerPage`），本轮未修，不计入。要凑数量得自己开发 N 个功能页 —— 那就变成「做自己的 App」，须在定位里讲清。
- **S6 用户自定义快捷方式**：用户自己填 `{bundleName, uri, parameters}`，UI 明示「未验证，需自行确认落点」，失败仍按「暂无可用直达入口」报告、不回退首页。这是把数据主权交给用户，也是数量最可控的一档。

### 3.6 明确排除（写进边界，防止回潮）

- 微信扫一扫、支付宝付款码、高德打车等**私有子页**：App 未公开声明可带参标准意图，两轮扩大检索 + 286 包 harvest 后仍无 URI，不编造。
- 元服务 / 服务卡片枚举：`@ohos.app.form.formHost.d.ts` 全 namespace `@systemapi` + `GET_BUNDLE_INFO_PRIVILEGED`，普通 App 用不了（结论已由开源源码坐实）。
- 裸 `scheme://` 隐式启动：会弹 chooser，违反「显式 bundleName」硬约束。
- 任何运行时多路由遍历 / 失败回退 App 首页：违反产品 Spec §7。

---

## 4. 落地约束（与现有实现逐条对齐）

1. **单路由**：`AtomicFunction.route` 仍是一条；S2 的 `parameters` 是这条路由自带的参数，不是第二条路由。
2. **显式**：`buildWant()` 对四种既有 kind 都写 `bundleName`；S3 (`vertical`) 走独立分支、由系统按 type+sceneType 匹配（非隐式 uri 认领），见 §2.0。
3. **失败即报告**：`NO_AVAILABLE_ENTRY` + 「暂无可用直达入口」，不降级、不兜底。
4. **分类固定 9 类**：`支付, 购物, 出行, 社交, 生活, 娱乐, 健康运动, 工具效率, 其他`；新卡片只能归入已有类。
5. **安装感知（P7）**：`canOpenLink` / 安装快照只证明「装了 + 声明了」，**不证明这页能打开**；P7 的模板/定时刷新若与本清单合并，晋级条件仍必须是「截图确认落点」。P7 实现计划已写好但**尚未执行**，本稿不触发它。
6. **证据分级**：`capabilities.json` 只收 L0 / L0+；L1/L2/L3 留在 `discovery-candidates.json` 的「已声明，待验证」或新增「垂类场景」字段，绝不混进可直接点击目录。
   ⚠ **但有一个既存冲突必须一起处理**：`RefreshOrchestrator` → `EffectiveCatalog.build()` 会把**已安装但未验证的模板候选**以 `source:'template', confidence:0.5` 合并进 `input.l1` 生成卡片，并按 `appName` 隐藏已验证条目。这与「卡片只暴露截图确认的直达入口」正面冲突，也和本稿 §3.6 的边界冲突。收敛实现时必须先裁定：要么给 `EffectiveCatalog` 加「只收 L0」过滤，要么彻底关掉模板注入（涉及 P7 的 D3/D4 语义，属产品形态决策，本稿不擅自改）。**不处理这一条，清单再干净，真机上仍会冒出没验证过的卡片。**
7. **参数类型**：见 §2.1，实现期先写失败单测再放宽类型。
8. **真包签名**：AGC 401 装机仍阻塞；用户已指示「后续签名一下就行了」，本稿不碰。

---

## 5. 建议的下一步（等你拍板，不擅自动）

1. **确认产品定位**：A「本设备可用能力 + 自有功能」/ B「纯自有功能集」/ C「维持原定位、接受个位数直达」。本稿按 A 写。
2. 确认后走架构流程：写新 Spec（或现有产品 Spec 的增补章节）→ 写实现计划 → 再改代码。
3. 实现第一批只做：参数类型放宽 + 1 条 `explicit-amap-routeplan` 卡片 + 9 类垂类入口的骨架，**每加一格都配一张真机截图**。
4. 并行修 `explorer` 空白页（独立缺陷）与 AGC 签名（用户另行安排时间）。

---

## 6. 本稿的诚实边界

- 只写文档，**没有**改 `capabilities.json`、没有改 `AtomicFunction.ets` / `LaunchDispatcher.ets`、没有改任何 Spec、没有重建/重装 HAP、没有新建 git / commit / push。
- 高德之外的显式带参落点（百度 / 花瓣）**未验证**，不宣称成功；首次系统确认框与隐私协议是预期阻挡，需用户过一次。
- L1 的 finance / flight / express 五类**未真机验证**，依据是官方映射文档，标「待验」。
- 当前测试基线：`node test/run.mjs` → **127 tests / 31 suites / 127 pass / 0 fail**（本轮新跑，非引用旧数字）。
- 清单里的 uri 全部来自 `bm dump -n` 官方声明，无一条编造。
