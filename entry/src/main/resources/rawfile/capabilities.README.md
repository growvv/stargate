# 能力库种子（capabilities.json）— 2026-11-09 第 4 轮

- **政策反转（用户 2026-11-09 拍板）**：真机点击后**只要有反应就保留** —— 目标 App 首页、登录页、注册页、隐私/授权同意页、系统同意弹窗、列出目标 App 的「选择打开方式」都算有反应。需要用户自己完成的登录与协议同意由用户人工完成；产品只负责把入口保留住并如实标注。
- **只剔除明确不能**：界面出现「暂无可用打开方式」、启动报 `10103101`、或点击后前台无任何变化。
- **复验纠偏**：首轮 52 条「剔除」全部二次复验 —— 先关掉上一条失败残留的系统「暂无可用打开方式 / 知道了」弹窗（它会遮住后续布局树），再冷启动并最多等 14 秒。结果 **6 条改判为有反应**（京东、快手、抖音），已并入种子；复验后剩余 46 条全部是明确的「暂无可用打开方式 / 启动失败」，不再有「无反应」这种不确定判定。
- **本轮规模**：143 个候选入口（58 个 App）逐条真机点开 → **97 个有反应**，其中 **96 个能归到具体 App**（通用选择器未列出目标 App 的不挂名）；按「同一 App 同一功能只留一条最具体路由」去重后 **64 条**能力卡；另加 1 条显式带参高德路线卡（`explicit-amap-routeplan`）和 9 条系统垂类卡（`vertical`）→ 种子共 **74 条**，覆盖 **39 个包名**。
- **判定计数**：DROP_NO_HANDLER=46，KEEP_OPEN=91，KEEP_CHOOSER=6。剔除 46 条「暂无可用打开方式/启动失败」、0 条「点击后前台无变化」；两者**不写入种子**。
- **hint 分布**：`(直接打开)` × 51 · `需登录` × 4 · `需同意` × 15 · `选择打开` × 4。`hint` 只标可可靠识别的状态；不猜测「首页」。
- **L0 过滤不变**：`EffectiveCatalog.build()` 只放行 `isL0(fn)` —— `source ∈ { linkFeature, scheme, shortcut, manual }` 且 `confidence >= 0.85`。`template`(0.5) / `rea`(0.6) / `injection`(0.2) 永不进卡片。
- **去重规则**：同一 `bundle + 功能标签` 只保留「有反应且 URI 最具体」的一条；不同功能（打开 App / 存储空间 / 通知设置 / 路线规划 / 登录 / 扫一扫 …）分别保留。原始 143 条结果全部保留在 `a3-probe/evidence/probe9-results.json`，证据不丢。
- **明确不能的选择器不进产品**：22 个 App 共用同一个 `file://` 系统文件选择器；若选择器文本里没有目标 App 名，说明这次点击并没有指向该 App，不挂该 App 的名字发卡。
- **卡片模型不变**：每条 `AtomicFunction` 仍只有一条 `route`（无 `routes[]`、无 `home` kind）；`capabilities.json` 仍是 HAP 内**唯一可直接点击目录**。`RouteKind` 仍为 5 种：`want / deeplink / applinking / shortcut-param / vertical`。
- **参数纪律**：`Route.parameters` 值类型 `string | number | boolean`；浮点经纬度必须原样传 `number`，不可字符串化、不可截断（CLI `--pi` 只能传整数，0/0 坐标算不出路线）。高德 `systemnav://routeplan` 的参数键名已真机验证；**禁止把高德参数表复制给百度/花瓣**。
- **D5 外部可替换**：`CapabilityRepository.fromContext()` 优先读取 `/data/storage/el2/base/haps/entry/files/capabilities.json`（`hdc file send` 即可替换，不重打包、不建服务端、不上云）。

## 种子构成

| 类别 | 条数 | 说明 |
|---|---|---|
| 真机有反应 · 去重后 | 64 | 目标 App 前台 / 登录注册 / 隐私同意 / 应用选择器 |
| 显式带参高德路线 | 1 | `explicit-amap-routeplan`：真浮点终点，一次点击直达路线结果页 |
| 系统垂类（选应用） | 9 | 走 `startAbilityByType`，系统按 `type + sceneType` 弹应用选择 |

## 垂类入口的证据边界（必须如实展示）

- `navigation/1`（RoutePlan）、`navigation/2`（Navigation）、`navigation/3`（PlaceSearch）、`mail/1`（ComposeMail）：**真机面板已验**；`navigation/1` 选高德后落到带参路线结果页。
- `finance/1`（Transfer）、`finance/2`（CreditCardRepayment）、`flight/1`（QueryByFlightNo）、`flight/2`（QueryByLocation）、`express/1`（QueryExpress）：**官方映射文档确认，真机落点待验**，只写 `verticalType + sceneType`，不预填臆测业务参数；不得计入「已验证直达」宣传口径。
- 垂类卡片会弹一次系统应用选择，UI 必须标明「选应用」，不伪装成一键直达。
- vertical 卡片的 `bundleName: com.stargate.functionpanel` 表示卡片归属本应用，**不是** Want 的目标包；`LaunchDispatcher` 的 vertical 分支不构造 Want、不调用 `startAbility`。

## 候选能力面

`discovery-candidates.json`（48 个 App）与 `app_templates.json` 只是候选面，永不直接生成卡片。本轮候选来自：前 1–3 轮已点过的 bundle+URI、286 包 `bm dump` 的官方 linkFeature 声明、以及没有其它入口的 App 的 scheme 根。`a3-probe/evidence/probe9-results.json` 保留全部 143 条真机反应证据（含剔除项），`probe9-candidates.json` 是可复跑的候选清单。
