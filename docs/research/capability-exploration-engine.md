# 应用能力探索引擎：证据分层与面板契约

本文把当前工程里的能力扫描、启动验证、静态逆向和 UI 测试入口整理成一个可落地的探索引擎。它描述的是**证据和状态**，不是把某个应用的声明直接伪装成可用功能。

## 当前事实

`probe/capability_scan.tsv` 是声明层扫描结果，共 48 个 bundle：

- 17 个 bundle 声明了 shortcut；
- 22 个 bundle 声明了 linkFeature；
- 37 个 bundle 至少声明了一个 scheme；
- 11 个 bundle 没有发现 scheme，不能被 scheme 探测器验证。

这些字段只能说明“包内或系统注册表中存在相关声明”。它们没有证明 URI 能打开目标原子页面，也没有证明 shortcut 参数在当前版本仍然有效。扫描结果应进入候选区，不能直接写入 `capabilities.json`。

`probe/aa_start_landing_probe.md` 记录了当前真机验证边界：`aa start` 返回成功只表示 Want 被派发或解析。经过第二轮截图复核，当前已有 4 条确认落到原子子页的路由进入 `capabilities.json`：高德路线规划、京东存储空间、微博存储空间、夸克千问助手。支付宝、微信和高德打车等候选仍落在登录页、首页或无法确认的页面，因此没有进入能力库。

`probe/card_feasibility.md` 记录了运行时边界：卡片事件经 `FormAbility.onFormEvent` 接收，卡片侧没有 `startAbility`；真正的第三方启动必须回到 `EntryAbility`/UIAbility。`uitest` 只用于测试态验证本工程自己的 HAP 和卡片，不在第三方应用内做无障碍注入或模拟点击。

## 分层模型

每个应用和功能都应保留一条记录，`evidence` 数组保存来源，`status` 由证据门控产生。层级从强到弱如下：

| 层级 | 来源 | 可以证明 | 不能证明 | 默认状态 |
| --- | --- | --- | --- | --- |
| L0 | 人工确认的入口和落点截图 | 当前版本、当前设备可用的具体功能 | 其他版本或设备仍可用 | `verified` |
| L1 | `bm dump -n <bundle> -s` shortcut 声明 | 应用公开了一个快捷入口及其参数形状 | 参数是否仍被业务页接受、是否需要登录 | `declared` |
| L2 | linkFeature / 系统注册 scheme | 包声明了可解析的 link 或 scheme | 解析后是否是原子页，而不是首页 | `declared` |
| L3 | `bundleManager.canOpenLink` 或等价系统解析探测 | 当前设备存在一个可解析的处理者 | 处理者会展示哪一个业务页面 | `installed` |
| L4 | REA 对 HAP/二进制/资源的静态分析 | 代码、字符串、路由表或参数中存在候选入口 | 静态候选一定可执行，或运行时登录状态满足 | `reverse_candidate` |
| L5 | `uitest`/人工运行时观察 | 页面树、文本和前台 Ability 与目标匹配 | 证明第三方内部逻辑稳定、可长期自动化 | `runtime_observed` 或 `rejected` |

只有 L0 或 L5 明确确认目标原子页时，记录才允许进入 `capabilities.json`。L1–L4 的记录可以出现在探索面板的“候选/待验证”分组中；它们不能触发一键直达。

## 统一记录形状

探索引擎的中间结果建议使用下面的 JSON 形状。它与现有 `AtomicFunction` 分开，避免把不确定候选混入生产目录：

```json
{
  "id": "com.alipay.mobile.client:shortcut:scan",
  "bundleName": "com.alipay.mobile.client",
  "appName": "支付宝",
  "label": "扫一扫",
  "category": "工具效率",
  "route": {
    "kind": "shortcut-param",
    "abilityName": "EntryAbility",
    "moduleName": "entry",
    "parameters": { "appId": "10000007" }
  },
  "status": "declared",
  "sourceLayer": "L1",
  "confidence": 0.7,
  "verifiedByProbe": false,
  "lastCheckedAt": 0,
  "evidence": [
    {
      "kind": "bm-dump",
      "path": "probe/capability_scan.tsv",
      "detail": "shortcut=scan"
    }
  ],
  "limitations": [
    "声明存在，但尚未证明落到原子功能页"
  ]
}
```

`status` 的允许值建议固定为 `declared`、`installed`、`reverse_candidate`、`runtime_observed`、`verified`、`rejected`、`unavailable`。`rejected` 必须带原因和证据，例如“`aa start` 成功但前台仅为 `EntryAbility`”。状态只能由更强证据提升，不能因为一次失败就删除较弱的声明证据。

## 面板如何使用这些状态

面板分成三个入口：

1. **可直接使用**：只读 `CapabilityRepository` 的 L0/L5 `verified` 条目，点击走现有 `LaunchDispatcher` 单路由；失败仍显示“暂无可用直达入口”，不回退首页。
2. **已发现候选**：显示 L1–L4 条目、来源层级、最近探测时间和限制。点击进入详情页，提供“在设备上验证”操作；验证结果写回探索记录，不直接写入已验证库。
3. **不可用/待分析**：列出没有 scheme、没有 shortcut 或已被运行时拒绝的应用。对这类条目提供“用 REA 分析包”“查看 UI 测试入口”等工程操作说明；这些操作不应在生产卡片中隐式执行。

安装感知仍可复用 P7 计划的 `canOpenLink` 探测和去抖，但它只负责过滤“本机未安装”的候选，不改变证据等级，也不把 `canOpenLink=true` 解释成原子页已验证。

## 三条探测流水线

### 1. 已开放入口

读取 `capability_scan.tsv`，再按 bundle 调用 `bm dump -n <bundle> -s` 解析 shortcut 参数，读取模块声明和 linkFeature。输出 `declared` 候选。每条候选应保留原始 bundle、scheme、shortcut id、参数和解析时间。

### 2. REA 静态分析

当声明层没有入口，或声明入口只落到首页时，针对**用户提供或设备已导出的 HAP/二进制**运行 REA：先做包成员和资源清单，再搜索 URI、Ability、路由表和字符串引用，最后沿候选入口追踪调用关系。静态结果只能写 `reverse_candidate`，并保留 Evidence ID、目标 SHA-256、分析范围和未知项。不要因为字符串命中就生成生产路由。

### 3. 系统运行时验证

对一个候选执行：停止目标应用 → 启动单条 Want → 读取前台 Ability → `uitest dumpLayout` 或人工截图确认页面文本/控件。只有页面证据与目标功能相符才提升为 `runtime_observed`/`verified`。设备无头、USB 弹窗、登录/风控或前台仍是 `EntryAbility` 时，结果应记为 `rejected` 或 `unavailable`，不能记为成功。

## 当前缺口

- `probe/README.md`、`probe/results/` 以及计划中 `scan_shortcut_params.py`、`launch_matrix.py`、`rea_route_probe.py` 等尚未落地；目前只有声明 TSV、卡片可行性探针和一次 `aa start` 记录。
- `capabilities.json` 只包含 4 条经过截图确认的 L0/L5 路由；其余 48 个 App 已投影到 `discovery-candidates.json` 和探索页，继续保留在独立候选区，避免把声明层或 REA 线索混入生产目录。
- 当前工作区没有第三方 App 原始 HAP；REA 已对本工程 HAP 做清单取证，但第三方 REA 路由分析必须等待设备导出目标 HAP。
- REA 和 UI 测试入口目前是工程/测试能力，不应直接打包进卡片运行时。面板可以展示分析结果和验证按钮，但执行器应在开发工具或受控测试环境中运行。
- 真实第三方应用的深层页面通常依赖登录、风控和版本内部状态；即使一次 L5 验证通过，也应记录设备、版本指纹和时间，并允许后续失效。

## 下一步实现顺序

1. 增加 `CapabilityDiscoveryRecord`/`DiscoveryStatus` 纯数据模型和本地 JSON 存储；先导入现有 TSV，生成全部 `declared` 候选。
2. 增加 shortcut/linkFeature 解析器和“候选详情”页；详情页明确显示证据层级和限制。
3. 增加受控验证适配器：UIAbility 侧启动单路由，记录前台 Ability、布局摘要和结果；失败不改变生产目录。
4. 接入 REA 导入结果（Evidence ID、SHA-256、候选 URI）并提供人工确认按钮；人工确认后才生成 `AtomicFunction`。
5. 最后把 L0/L5 `verified` 记录同步到 `capabilities.json`，保留回滚和失效标记。

