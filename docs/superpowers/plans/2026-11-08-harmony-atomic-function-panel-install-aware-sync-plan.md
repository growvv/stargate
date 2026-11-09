# 已安装应用感知 / 能力模板 / 定时刷新（P7）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让卡片与三个内页在每台设备上只显示「本机已安装且已探测到」的应用功能，新装/卸载在下次刷新自动增删，且不破坏既有失败反馈与视觉结构。

**Architecture:** 新增纯逻辑层 `AppTemplateCatalog / InstalledProbe / EffectiveCatalog / CatalogDiff` 与两个薄 SDK 边界 `InstallSnapshotStore / RefreshOrchestrator`；`RefreshOrchestrator.effectiveRepository(context)` 是**唯一有效目录出口**，`CardBinding.compose` 仍是**唯一绑定组装点**，`WidgetCard.ets` 零改动。L1=`capabilities.json`（已验证层），L2=`app_templates.json`（模板候选层，仅 `canOpenLink===true` 才显示）；`CatalogDiff.confirm` 用带符号 `streak` 做「连续 2 次一致」去抖。探测只在 `FormAbility` / `EntryAbility` / 页面侧执行，卡片只消费 `formBindingData`。

**Tech Stack:** ArkTS / HarmonyOS NEXT Stage model / API 26；`bundleManager.canOpenLink` + `module.querySchemes`；`formProvider.updateForm` / `formBindingData` / `FormExtensionAbility`；`@ohos.data.preferences`；`form_config.json` (`updateDuration`)；卡片侧 `@LocalStorageProp` + `Flex(wrap)`+`Stack` 嵌套框；测试用 Node 26 strip-types + `test/loader.mjs` + `test/shims/` + `@ohos/hypium` shim；构建/验签/装机用 `hvigorw` / `hap-sign-tool.jar` / `hdc` / `uitest`。

**Spec:** `docs/superpowers/specs/2026-11-08-harmony-atomic-function-panel-install-aware-sync-design.md`（下称「本 Spec」）；权威主文档 `docs/superpowers/specs/2026-11-07-harmony-atomic-function-panel-product-design.md`（下称「主文档」）。执行者两篇都读；引用约定按本 Spec §0 的「引用约定」执行。

## Global Constraints

- 纯 HarmonyOS NEXT / ArkTS / Stage / HAP / API 26；真机 `5KPBB25927200695`（HarmonyOS 7.0.0.109）。
- 卡片 `WidgetCard.ets` 内**禁用** SDK / 文件系统 / 网络 / 定时器 / `@State`；所有探测在 `FormAbility` / `EntryAbility` / 页面侧执行（主文档 §1.4）。卡片本轮**零改动**。
- 不枚举全机已安装应用、不调用 `getBundleInfo`（需系统应用权限）；唯一探测手段 `bundleManager.canOpenLink(link): boolean`（API 12+、`@atomicservice`）。
- `module.querySchemes`：数组、≤50 项、每项 `^[a-zA-Z][0-9a-zA-Z+.-]*`、≤128 字符；每个非空 `scheme` 必须声明，否则 `canOpenLink` 抛 `17700056`。
- `canOpenLink` 抛 `17700056` / `17700055` / 权限异常 → 视为 `false`；单条失败不中断整批、不崩、不误报空态；整批 SDK 不可用时沿用上次快照，**不清空卡片**。
- 两层目录：L1 = `capabilities.json`（A3/D5，已验证层）；L2 = `app_templates.json`（模板候选层）。L2 **只在** `canOpenLink(template.scheme)===true` 时显示；L2 **不写入** `capabilities.json`，产品空种子 `{items:[]}` 立场不破坏。
- L2 条目 `source:'template'`、`confidence` 低值、`verifiedByProbe=false`；`canOpenLink=true` **不证明**子功能落地。只承诺「零未安装死链」，**不承诺「零失效项」**；scheme 未由 Task 0 查得者保持 `''`，不参与探测、不显示，**禁止编造**。
- 去抖：同一 id **连续 2 次**探测结果一致才确认增删；`streak` 结果变化时归 1、一致时 +1、达到 2 才改变已确认 `installedIds`。平台周期刷新最快 30 分钟；**不承诺秒级即时**。
- `form_config.json`：`updateDuration` 单位 30 分钟、最快 30 分钟；与 `scheduledUpdateTime` 二者同配则**定点优先**。按 Task 0 结论去掉 `scheduledUpdateTime`，保留 `updateEnabled:true` 与 `updateDuration:1`。
- 失败处理**完全沿用主文档 §4.3**：明确提示「『X』暂无可用直达入口」+ 失效小圆点；**不回退首页、不试其他路由、不做运行时降级**。探测只决定「显不显示」，不参与点击时的路由选择。
- 与 D2 失败态刷新解耦：`RefreshOrchestrator.resolve` **原样透传** `failure` / `failureAt`（TTL 仍在 `CardBinding.compose` 内用 `CardFeedback.visibleAt` 判定），不重算、不清空；`setFormNextRefreshTime` 仍只服务失败 TTL（`FAILURE_CLEAR_MINUTES=1`），不为安装刷新额外排定时器。
- `ForEach` 的 key 必须含内容（label + 各 item.id）；卡片内不引入 `Grid` / `Scroll`（无 `@form` 支持），沿用 `Flex(wrap)` + `Stack` 嵌套框；8 位十六进制颜色是 **AARRGGBB**（alpha 在首位）。
- ArkTS 约束：`arkts-no-untyped-obj-literals`（显式 interface）、`arkts-no-indexed-signatures`、`arkts-no-structural-typing`；不用 TS `enum` / 参数属性 / 对象 spread（尤其编译进 `widgets.abc` 的代码）。
- 不针对真实第三方 App 做 L5 注入 / 无障碍攻击；不改技术预研 Spec；不改既有产品 Spec 正文；决策增量以「决策变更记录」写入 SDD ledger，不写进主文档正文。
- 不建 git / 不 commit / 不 push / 不 publish / 无向外写。签名口令 / AGC accessToken 只在内存中使用，**绝不**出现在日志、证据文件、HTML 报告、计划或 Spec；日志用 `***` 脱敏。
- 真实包名 `com.stargate.functionpanel` 现场安装仍被 AGC accessToken 过期（401）阻塞；真机演示用一次性 `com.example.minimal` 对照构建 + `TEST FIXTURE ONLY` 数据，**如实报告阻塞、不静默绕过**。
- 保留 SDD 工作区作验收证据；不重启视觉伴侣服务 `bmgzozvm4`；不调用 `Workflow`。
- TDD 铁律：任何生产代码改动前先写失败测试、亲眼看它失败、最小实现、全量套件绿；失败用 `superpowers:systematic-debugging` 查根因。
- 本工程无 git 仓库：每个任务以「记录产物/校验」步骤替代 `git commit`。测试装置：`test/run.mjs`（全量）、`test/run-one.mjs <Suite.test.ets>`（单套件）、`test/loader.mjs` + `test/shims/`。每个任务在写测试时把**自己的**套件追加进 `run.mjs` 的 `suites`，使全量套件始终只含已实现项、始终绿。

## Review Focus

1. **所有模板 `scheme===''`**（Task 0 未查得任何真实 scheme）：`installedIds` 为空、L2 不产出条目，卡片必须仍按 L1 / 诚实空态渲染，不空白、不崩溃 → 测试钉在 Task 3。
2. **某一条 `canOpenLink` 抛 `17700056`**：该模板视为 `false`，整批继续，上次已安装快照不被清空 → 测试钉在 Task 2。
3. **探测抖动 `true→false→true`**：连续 2 次一致才确认，卡片不闪烁 → 测试钉在 Task 4。
4. **安装刷新发生时正处于 D2 活跃失败态**：`binding` 必须保留 `failure` 文案与 `failureAt`，TTL 不被提前清除 → 测试钉在 Task 6。
5. **直接打开全量/分类/配置页（不经过卡片）**：三个内页必须与卡片用同一份有效目录，不出现已卸载 L1 残留、不漏 L2 → 静态源码断言测试钉在 Task 7。

---

## File Structure

| 文件 | 职责 | SDK | 新增/修改 |
|---|---|---|---|
| `entry/src/main/resources/rawfile/app_templates.json` | L2 模板数据（D5 可替换），scheme 由 Task 0 回填 | 数据 | 新增 |
| `entry/src/main/ets/data/AppTemplateCatalog.ets` | 模板解析/校验 + rawfile 同步读取 | `common.Context`（已 shim） | 新增 |
| `entry/src/main/ets/model/AtomicFunction.ets` | `SOURCE_CONFIDENCE` 增 `'template'` 取值 | 无 | 修改 |
| `entry/src/main/ets/data/InstalledProbe.ets` | `SchemeProbe` 契约 + `installedIds` 纯逻辑 + `BundleSchemeProbe` 生产适配器 | `@ohos.bundle.bundleManager` | 新增 |
| `entry/src/main/ets/data/EffectiveCatalog.ets` | L1+L2 合并 / 未安装过滤 / 去重 / 稳定排序 | 无 | 新增 |
| `entry/src/main/ets/data/CatalogDiff.ets` | `diff` / `confirm`（带符号 streak 去抖）/ `resetDebounce` | 无 | 新增 |
| `entry/src/main/ets/data/InstallSnapshotStore.ets` | Preferences 持久化快照 + `fromMemory()` 内存路径 | `@ohos.data.preferences` | 新增 |
| `entry/src/main/ets/form/RefreshOrchestrator.ets` | 纯 `resolve(input)` + SDK `effectiveRepository(context)`（唯一有效目录出口） | 上述边界 | 新增 |
| `entry/src/main/module.json5` | `module.querySchemes` 白名单（≤50） | 配置 | 修改 |
| `entry/src/main/resources/base/profile/form_config.json` | 去掉 `scheduledUpdateTime` | 配置 | 修改 |
| `entry/src/main/ets/form/FormAbility.ets` | `binding()` 改走 `RefreshOrchestrator.resolve` | 既有 | 修改 |
| `entry/src/main/ets/entryability/EntryAbility.ets` | `pushCardResult` / `runLaunch` / 页面拉起时主动刷新改走有效目录 | 既有 | 修改 |
| `entry/src/main/ets/pages/{AllFunctions,Category,Config}Page.ets` | `fromContextSync` → `effectiveRepository` | 既有 | 修改 |
| `test/shims/manifest.json` / `_common.mjs` / `@ohos.bundle.bundleManager.mjs` | Node 测试用 SDK shim | — | 新增/修改 |
| `test/run.mjs` | 逐任务登记新套件 | — | 修改 |
| 6 个 `entry/src/test/*.test.ets` | 每任务一套 RED→GREEN | — | 新增 |
| `.superpowers/sdd/<this-plan>/` | ledger / 探针结论 / 截图 / HTML 报告 | — | 新增 |

**依赖方向**：纯逻辑（AppTemplateCatalog.parse / InstalledProbe.installedIds / EffectiveCatalog.build / CatalogDiff.*）→ 薄边界（InstallSnapshotStore / RefreshOrchestrator）→ Ability / 页面。反向依赖禁止。

---

### Task 0: 一次性真机探针（先证可行，再写实现代码）

**Files:**
- Create: `.superpowers/sdd/2026-11-08-harmony-atomic-function-panel-install-aware-sync-plan/probe/conclusions.md`（结论文档，**不是**产品代码）
- Modify（临时、探针结束后还原）：`entry/src/main/module.json5`（临时 `querySchemes`）、`form_config.json`（临时去掉 `scheduledUpdateTime`）

**Interfaces:**
- Consumes: 本 Spec 附录 A 的 SDK 证据、真机 `5KPBB25927200695`、既有 `hdc` / `uitest` / `hidumper -s FormMgr` 链路。
- Produces: ① `CAN_OPEN_LINK_OK: boolean`；② `PERIODIC_REFRESH_OK: boolean`（去掉定点后 `refreshCount` 是否递增 / `isCountTimerRefresh`）；③ `VERIFIED_SCHEMES: Record<templateId, scheme>`（只填真机查得者，未查得留 `''`）；④ `SYSTEM_LINK_OK: boolean`（系统应用能否用 link 形式探测）。

> **TDD 例外**：这是一次性、可丢弃的可行性探针，不写产品代码、不需要失败测试（沿用本工程既有 Task 0 惯例，记入 ledger）。

- [ ] **Step 1:** 在 `module.json5` 临时声明 1–2 个**真实存在**的 scheme，编译安装对照构建，调用 `canOpenLink` 观察返回值；记录 `CAN_OPEN_LINK_OK`。Expected: 结论写入 `conclusions.md`，含原始命令输出摘要（口令/token 脱敏）。
- [ ] **Step 2:** 临时去掉 `form_config.json` 的 `scheduledUpdateTime`，装机后用 `hidumper -s FormMgr -a '-r'` 与 `'-i <formId>'` 观察 `refreshCount` / `isCountTimerRefresh` / `updateDuration [1800000]`；记录 `PERIODIC_REFRESH_OK`。Expected: 至少一组刷新前后计数对比写入 `conclusions.md`。
- [ ] **Step 3:** 为附录 B 的候选 App 工程侧查得真实 scheme（SDK 声明 / 已安装应用清单 / 公开资料），**只回填可查证者**；无法查得者保持 `''`。记录 `VERIFIED_SCHEMES`。Expected: `conclusions.md` 的表格逐行标注「查得 / 未查得」，**0 条编造**。
- [ ] **Step 4:** 检查 `kind:'system'` 应用（电话/相机/设置…）是否能以 link 形式让 `canOpenLink` 返回真；记录 `SYSTEM_LINK_OK`。不能者保持 `scheme=''`、`kind:'system'`，不显示。
- [ ] **Step 5:** 还原 `module.json5` / `form_config.json` 的临时改动（Task 2 / Task 7 会正式落地）。写出 `conclusions.md` 的「Go / No-Go」段：若 `CAN_OPEN_LINK_OK=false` → **如实报告并回到工程层换方案**（退回「仅 A3 已验证条目 + 用户自行替换配置文件」），**不在运行时偷偷兜底**，后续实现任务不启动。Expected: `conclusions.md` 含明确 Go/No-Go 一行。
- [ ] **Step 6: 记录产物/校验** — 在 SDD ledger 追加 `Task 0: Ruling: …`（探针为 throwaway、无产品代码）+ 四项结论 + `Task 0: complete`。Expected: ledger 有该行；`git` 相关命令执行数为 0。

---

### Task 1: 模板目录 `AppTemplateCatalog` + `app_templates.json` + `SOURCE_CONFIDENCE`

**Files:**
- Create: `entry/src/main/ets/data/AppTemplateCatalog.ets`
- Create: `entry/src/main/resources/rawfile/app_templates.json`
- Modify: `entry/src/main/ets/model/AtomicFunction.ets:33-40`（`SOURCE_CONFIDENCE` 增 `'template': 0.5`）
- Test: `entry/src/test/AppTemplateCatalog.test.ets`
- Modify: `test/run.mjs`（`suites` 追加 `'./AppTemplateCatalog.test.ets'`）

**Interfaces:**
- Consumes: `CATEGORIES`、`Route` / `RouteKind`（`AtomicFunction.ets`）、`CapabilityRepository.decodeUtf8`（`ET` 文件，静态）。
- Produces:
  ```ts
  export interface TemplateFunction { label: string; route: Route; }
  export interface AppTemplateEntry {
    id: string; appName: string; bundleName: string; category: string;
    scheme: string; kind: 'third-party' | 'system' | 'unknown';
    functions: TemplateFunction[]; verifiedByProbe: boolean;
  }
  export interface AppTemplateSeed { templates: AppTemplateEntry[]; }
  export class AppTemplateCatalog {
    static parse(text: string): AppTemplateEntry[];          // 纯逻辑，非法/空 → []
    static schemes(entries: AppTemplateEntry[]): string[];    // 去空、去重、排序
    static fromEntries(entries: AppTemplateEntry[]): AppTemplateCatalog;
    static fromContextSync(context: common.Context): AppTemplateCatalog; // rawfile 'app_templates.json'
    entries(): AppTemplateEntry[];
  }
  ```
  `parse` 校验：`id`/`appName` 非空、`category ∈ CATEGORIES`、`kind ∈ {'third-party','system','unknown'}`、`functions` 数组且每项 `label` 非空 + `route.kind ∈ {'want','deeplink','applinking','shortcut-param'}`；`scheme` 非空但不匹配 `^[a-zA-Z][0-9a-zA-Z+.-]*` 时**强制置 `''`**（不抛 `17700055`，诚实不探测）。

- [ ] **Step 1: 写失败测试** — 在 `AppTemplateCatalog.test.ets` 写 5 个 `it`，并把套件追加进 `run.mjs`：
  ```ts
  it('parse_keeps_valid_templates_and_rejects_bad_category_and_route_kind', 0, () => {
    const out = AppTemplateCatalog.parse(JSON.stringify({ templates: [
      { id:'tpl:alipay', appName:'支付宝', bundleName:'com.eg.alipay', category:'支付',
        scheme:'alipays', kind:'third-party', verifiedByProbe:false,
        functions:[{ label:'付款码', route:{ kind:'deeplink', uri:'alipays://x' } }] },
      { id:'tpl:bad', appName:'X', bundleName:'b', category:'不存在', scheme:'x',
        kind:'third-party', verifiedByProbe:false, functions:[{ label:'y', route:{ kind:'home' } }] }
    ]}));
    expect(out.length).assertEqual(1);
    expect(out[0].id).assertEqual('tpl:alipay');
  });
  it('parse_returns_empty_on_invalid_or_empty_text', 0, () => {
    expect(AppTemplateCatalog.parse('').length).assertEqual(0);
    expect(AppTemplateCatalog.parse('{oops').length).assertEqual(0);
  });
  it('parse_blanks_an_invalid_scheme_instead_of_probing_it', 0, () => { /* '1bad:' → scheme='' */ });
  it('schemes_are_unique_sorted_and_at_most_50', 0, () => { /* ≤50, 无 '', 无重复 */ });
  it('source_confidence_has_template_value_below_scheme', 0, () => {
    expect(SOURCE_CONFIDENCE['template']).assertEqual(0.5);
    expect(SOURCE_CONFIDENCE['template'] < SOURCE_CONFIDENCE['scheme']).assertTrue();
  });
  ```
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs AppTemplateCatalog.test.ets` → Expected: FAIL（`ERR_MODULE_NOT_FOUND .../data/AppTemplateCatalog.ets`），exit 1。
- [ ] **Step 3: 最小实现** — 按 Interfaces 写 `AppTemplateCatalog.ets`（`fromContextSync` 用 `context.resourceManager.getRawFileContentSync('app_templates.json')` + `decodeUtf8` + `parse`，异常 → `[]`）；`AtomicFunction.ets` 的 `SOURCE_CONFIDENCE` 增 `'template': 0.5`（决策变更登记进 ledger）。
- [ ] **Step 4: 写 `app_templates.json`** — 按本 Spec §4.2 / 附录 B 展开 25 个候选 App（9 类目），`verifiedByProbe:false`，`scheme` = Task 0 `VERIFIED_SCHEMES` 的对应值或 `''`（未查得），`kind:'system'` 单列、`scheme:''`。每候选 1–4 个 `functions`，`route` 用 Task 0 查得的候选路由；**未查得路由的 function 不写入**（不编造）。Expected: `AppTemplateCatalog.schemes(parse(...))` 全部匹配 `^[a-zA-Z][0-9a-zA-Z+.-]*` 且 ≤50。
- [ ] **Step 5: 跑测试确认通过** — Run: `node test/run-one.mjs AppTemplateCatalog.test.ets` → Expected: PASS 5/5；`node test/run.mjs` → Expected: 全绿（既存 94 + 5）。
- [ ] **Step 6: 记录产物/校验** — ledger 追加 `Task 1: Ruling: 'template' 置信度取 0.5 并登记为 A3 决策变更 — 低于 scheme(0.85) 以体现「落地未验证」 — cost if wrong: 排序权重 W_CONF=0.05 的微小偏移` + `Task 1: complete (tests: node test/run.mjs → <N>/<N> PASS)`。Expected: ledger 有该行。

---

### Task 2: `InstalledProbe` + `querySchemes` + SDK shim

**Files:**
- Create: `entry/src/main/ets/data/InstalledProbe.ets`
- Create: `test/shims/@ohos.bundle.bundleManager.mjs`
- Modify: `test/shims/manifest.json`、`test/shims/_common.mjs`
- Modify: `entry/src/main/module.json5`（`module.querySchemes`）
- Test: `entry/src/test/InstalledProbe.test.ets`
- Modify: `test/run.mjs`（登记套件）

**Interfaces:**
- Consumes: `AppTemplateEntry`（Task 1）。
- Produces:
  ```ts
  export interface SchemeProbe { canOpen(scheme: string): boolean; }
  export class BundleSchemeProbe implements SchemeProbe {
    canOpen(scheme: string): boolean;   // 包装 bundleManager.canOpenLink，异常 → false
  }
  export class InstalledProbe {
    static installedIds(templates: AppTemplateEntry[], probe: SchemeProbe): string[];
  }
  ```
  `installedIds`：跳过 `scheme===''`、`verifiedByProbe` 不参与判定；逐条 `try { probe.canOpen(t.scheme) } catch → false`；`true` 则收集 `t.id`；返回**按 id 升序**的数组。

- [ ] **Step 1: 写失败测试 + shim 骨架** — `InstalledProbe.test.ets` 用**注入的假探针**（不碰 SDK）写 4 个 `it`：
  ```ts
  it('installed_ids_are_only_templates_whose_scheme_opens', 0, () => {
    const ts = [ tpl('tpl:a','schemeA'), tpl('tpl:b','schemeB'), tpl('tpl:c','') ];
    const ids = InstalledProbe.installedIds(ts, { canOpen: (s) => s === 'schemeA' });
    expect(ids.length).assertEqual(1); expect(ids[0]).assertEqual('tpl:a');
  });
  it('empty_scheme_never_calls_the_probe', 0, () => { /* 计数断言 */ });
  it('one_throwing_probe_is_false_and_does_not_abort_the_batch', 0, () => {   // Review Focus #2
    const probe = { canOpen: (s) => { if (s==='bad') throw new Error('17700056'); return s==='ok'; } };
    const ids = InstalledProbe.installedIds([tpl('tpl:x','bad'), tpl('tpl:y','ok')], probe);
    expect(ids.length).assertEqual(1); expect(ids[0]).assertEqual('tpl:y');
  });
  it('installed_ids_are_sorted_for_determinism', 0, () => { /* 反序输入 → 升序输出 */ });
  ```
  同一步把 `@ohos.bundle.bundleManager` 加入 `manifest.json`（→ `@ohos.bundle.bundleManager.mjs`）、在 `_common.mjs` 增 `export const bundleManager = { canOpenLink: (_l: string) => false };`、建 shim 包装文件、登记 `run.mjs`。
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs InstalledProbe.test.ets` → Expected: FAIL（`ERR_MODULE_NOT_FOUND .../data/InstalledProbe.ets`），exit 1。
- [ ] **Step 3: 最小实现** — 写 `InstalledProbe.ets`：`BundleSchemeProbe.canOpen` 用 `import bundleManager from '@ohos.bundle.bundleManager'`，`try { return bundleManager.canOpenLink(scheme); } catch { return false; }`；`installedIds` 按上述规则，不 import 其它 SDK。
- [ ] **Step 4: 落地 `querySchemes`** — `module.json5` 的 `module` 增 `"querySchemes": [...]`，值 = `AppTemplateCatalog.schemes(模板)`（Task 0 的 `VERIFIED_SCHEMES` 非空者，去重、≤50）。Expected: 每个非空 `template.scheme` 都在该数组内；数组长度 ≤50。
- [ ] **Step 5: 跑测试确认通过** — Run: `node test/run-one.mjs InstalledProbe.test.ets` → Expected: PASS 4/4；`node test/run.mjs` → Expected: 全绿。
- [ ] **Step 6: 记录产物/校验** — ledger 追加 `Task 2: complete (tests …)` + `querySchemes` 实际条数（若为 0，记 `Ruling: Task 0 未查得真实 scheme → querySchemes 空数组，L2 暂不产出图标，属诚实降级而非运行时兜底 — cost if wrong: 演示覆盖有限`）。Expected: ledger 有该行。

---

### Task 3: `EffectiveCatalog`（L1+L2 合并 / 过滤 / 去重 / 稳定排序）

**Files:**
- Create: `entry/src/main/ets/data/EffectiveCatalog.ets`
- Test: `entry/src/test/EffectiveCatalog.test.ets`
- Modify: `test/run.mjs`（登记套件）

**Interfaces:**
- Consumes: `AtomicFunction` / `CATEGORIES` / `SOURCE_CONFIDENCE`（Task 1）、`AppTemplateEntry`（Task 1）、`CapabilityRepository.fromItems`。
- Produces:
  ```ts
  export class EffectiveCatalog {
    static build(l1: AtomicFunction[], templates: AppTemplateEntry[],
                 installedIds: Set<string>): AtomicFunction[];
  }
  ```
  规则（全部钉死）：
  1. `probedApps` = `installedIds` 命中的模板 `appName.toLowerCase()` 集合；`knownApps` = `scheme!==''` 的模板 `appName.toLowerCase()` 集合。
  2. L1 过滤：丢弃 `knownApps.has(appName.toLowerCase()) && !probedApps.has(appName.toLowerCase())` 的条目（已验证但本机已卸载）；其余保留。
  3. L2 生成：仅 `installedIds.has(t.id) && t.scheme!==''` 的模板，逐 `function` 生成 `AtomicFunction`，`id = t.id + ':' + fn.label`，`source:'template'`，`confidence = SOURCE_CONFIDENCE['template']`（0.5），`appName=t.appName`，`bundleName=t.bundleName`，`category=t.category`，`route=fn.route`。
  4. 去重：先收集保留的 L1（按 id），再追加 id 未出现的 L2；**L1 优先**。
  5. 稳定排序：最终数组按 `id` 升序（显示排序仍由既有 `RankingEngine.topN` 在 `CardBinding.compose` 内完成，不引入新维度）。

- [ ] **Step 1: 写失败测试** — 5 个 `it`（含 Review Focus #1）：
  ```ts
  it('uninstalled_app_drops_both_its_L1_and_L2_entries', 0, () => {
    const out = EffectiveCatalog.build([l1('fn-a','支付宝')],
      [tpl('tpl:alipay','支付宝','alipays',[fn('付款码')])], new Set<string>());
    expect(out.length).assertEqual(0);
  });
  it('installed_template_adds_L2_candidates_marked_template', 0, () => {
    const out = EffectiveCatalog.build([], [tpl('tpl:alipay','支付宝','alipays',[fn('付款码')])],
      new Set(['tpl:alipay']));
    expect(out.length).assertEqual(1);
    expect(out[0].id).assertEqual('tpl:alipay:付款码');
    expect(out[0].source).assertEqual('template');
    expect(out[0].confidence).assertEqual(0.5);
  });
  it('L1_wins_on_duplicate_id', 0, () => { /* 同 id 只留 L1 */ });
  it('result_is_sorted_by_id_for_reproducibility', 0, () => { /* 反序 → 升序 */ });
  it('no_template_has_a_scheme_still_renders_L1_and_never_crashes', 0, () => { // Review Focus #1
    const out = EffectiveCatalog.build([l1('fn-a','微信')],
      [tpl('tpl:wechat','微信','',[fn('扫一扫')])], new Set<string>());
    expect(out.length).assertEqual(1); expect(out[0].id).assertEqual('fn-a');
  });
  ```
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs EffectiveCatalog.test.ets` → Expected: FAIL（`ERR_MODULE_NOT_FOUND .../data/EffectiveCatalog.ets`），exit 1。
- [ ] **Step 3: 最小实现** — 按 5 条规则写 `EffectiveCatalog.ets`（零 SDK、零 import 其它任务文件除 model）。
- [ ] **Step 4: 跑测试确认通过** — Run: `node test/run-one.mjs EffectiveCatalog.test.ets` → Expected: PASS 5/5；`node test/run.mjs` → Expected: 全绿。
- [ ] **Step 5: 记录产物/校验** — ledger 追加 `Task 3: complete (tests …)`。Expected: ledger 有该行。

---

### Task 4: `CatalogDiff`（diff + 带符号 streak 去抖）

**Files:**
- Create: `entry/src/main/ets/data/CatalogDiff.ets`
- Test: `entry/src/test/CatalogDiff.test.ets`
- Modify: `test/run.mjs`（登记套件）

**Interfaces:**
- Produces:
  ```ts
  export interface InstallSnapshot {
    installedIds: string[]; probedAt: number;
    appVersionFingerprint: string; streak: Record<string, number>;
  }
  export interface CatalogDiffResult { added: string[]; removed: string[]; unchanged: string[]; }
  export class CatalogDiff {
    static empty(): InstallSnapshot;                       // installedIds=[], probedAt=0, fp='', streak={}
    static diff(prev: string[], next: string[]): CatalogDiffResult;
    static confirm(prev: InstallSnapshot, probed: string[], allIds: string[],
                   now: number): InstallSnapshot;
    static resetDebounce(prev: InstallSnapshot): InstallSnapshot;  // streak={}，保留 installedIds/fp
  }
  ```
  `streak` 为**带符号**计数：`>0` = 连续 `true` 次数，`<0` = 连续 `false` 次数（用有符号整数同时记住「上一次观测值」与「连续次数」，避免新增字段）。`confirm` 算法：
  ```
  for id of allIds (已排序):
    cur = probed.includes(id)
    s = prev.streak[id] ?? 0
    s = cur ? (s > 0 ? s + 1 : 1) : (s < 0 ? s - 1 : -1)
    streak[id] = s
    confirmed = s >= 2 ? true : (s <= -2 ? false : prev.installedIds.includes(id))
    if (confirmed) installedIds.push(id)
  return { installedIds, probedAt: now, appVersionFingerprint: prev.appVersionFingerprint, streak }
  ```
  `diff`：升序遍历并集，`added = next-prev`、`removed = prev-next`、`unchanged = prev∩next`，三数组均升序。

- [ ] **Step 1: 写失败测试** — 5 个 `it`（含 Review Focus #3）：
  ```ts
  it('diff_reports_added_removed_unchanged_sorted', 0, () => {
    const d = CatalogDiff.diff(['a','b'], ['b','c']);
    expect(d.added.join(',')).assertEqual('c');
    expect(d.removed.join(',')).assertEqual('a');
    expect(d.unchanged.join(',')).assertEqual('b');
  });
  it('a_flap_true_false_true_never_confirms_a_change', 0, () => {   // Review Focus #3
    let s = CatalogDiff.empty();
    s = CatalogDiff.confirm(s, ['a'], ['a'], 1000);
    s = CatalogDiff.confirm(s, [],    ['a'], 2000);
    s = CatalogDiff.confirm(s, ['a'], ['a'], 3000);
    expect(s.installedIds.length).assertEqual(0);
  });
  it('two_consecutive_true_then_false_confirms_install_then_remove', 0, () => {
    let s = CatalogDiff.empty();
    s = CatalogDiff.confirm(s, ['a'], ['a'], 1000);
    s = CatalogDiff.confirm(s, ['a'], ['a'], 2000);
    expect(s.installedIds[0]).assertEqual('a');
    s = CatalogDiff.confirm(s, [], ['a'], 3000);
    expect(s.installedIds.length).assertEqual(1);   // 第 1 个 false 不生效
    s = CatalogDiff.confirm(s, [], ['a'], 4000);
    expect(s.installedIds.length).assertEqual(0);   // 第 2 个 false 确认卸载
  });
  it('resetDebounce_clears_streak_but_keeps_confirmed_ids', 0, () => { /* fp 变化触发重探 */ });
  it('probedAt_is_the_now_argument', 0, () => { /* 4000 */ });
  ```
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs CatalogDiff.test.ets` → Expected: FAIL（`ERR_MODULE_NOT_FOUND .../data/CatalogDiff.ets`），exit 1。
- [ ] **Step 3: 最小实现** — 按 Interfaces 与算法写 `CatalogDiff.ets`（零 SDK）。
- [ ] **Step 4: 跑测试确认通过** — Run: `node test/run-one.mjs CatalogDiff.test.ets` → Expected: PASS 5/5；`node test/run.mjs` → Expected: 全绿。
- [ ] **Step 5: 记录产物/校验** — ledger 追加 `Task 4: Ruling: streak 用带符号整数编码「上次观测值 + 连续次数」，不新增 lastSeen 字段 — 保持本 Spec §5.3 快照形状不变 — cost if wrong: streak 语义需靠注释维护` + `Task 4: complete`。Expected: ledger 有该行。

---

### Task 5: `InstallSnapshotStore`（Preferences 持久化 + 内存路径）

**Files:**
- Create: `entry/src/main/ets/data/InstallSnapshotStore.ets`
- Test: `entry/src/test/InstallSnapshotStore.test.ets`
- Modify: `test/run.mjs`（登记套件）

**Interfaces:**
- Consumes: `InstallSnapshot`（Task 4）。
- Produces:
  ```ts
  const SNAPSHOT_STORE_NAME: string = 'atomic_function_install_snapshot';
  const SNAPSHOT_KEY: string = 'snapshot';
  export class InstallSnapshotStore {
    static fromContextSync(context: common.Context): InstallSnapshotStore; // preferences.getPreferencesSync
    static fromMemory(initial?: InstallSnapshot): InstallSnapshotStore;     // 无 SDK，供 Node 测试
    load(): InstallSnapshot;
    save(s: InstallSnapshot): void;
  }
  ```
  用 `type PrefHandle = preferences.Preferences`（真实 SDK 类型，规避 `arkts-no-structural-typing`；不自定义同形 interface）。`fromContextSync` 用 `getSync(SNAPSHOT_KEY, '{}')` + `typeof raw==='string'` 收窄 + `JSON.parse`，异常 → `CatalogDiff.empty()`。`load()` 返回内存快照；`save(s)` 更新内存并 `putSync` + `flushSync`（try/catch，失败不影响内存正确性）。`fromMemory` 不持有 `pref`。

- [ ] **Step 1: 写失败测试** — 4 个 `it`：
  ```ts
  it('fromMemory_round_trips_a_snapshot', 0, () => {
    const st = InstallSnapshotStore.fromMemory();
    const s = { installedIds:['a'], probedAt: 42, appVersionFingerprint:'v1', streak:{ a: 2 } };
    st.save(s); expect(st.load().installedIds[0]).assertEqual('a');
    expect(st.load().probedAt).assertEqual(42);
  });
  it('fromMemory_defaults_to_empty_snapshot', 0, () => {
    expect(InstallSnapshotStore.fromMemory().load().installedIds.length).assertEqual(0);
  });
  it('fromContextSync_reads_a_persisted_snapshot', 0, () => { /* 假 context 返回带 getPreferencesSync 的句柄 */ });
  it('fromContextSync_survives_corrupt_json', 0, () => { /* 'not-json' → empty，不抛 */ });
  ```
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs InstallSnapshotStore.test.ets` → Expected: FAIL（`ERR_MODULE_NOT_FOUND .../data/InstallSnapshotStore.ets`），exit 1。
- [ ] **Step 3: 最小实现** — 按 Interfaces 写 `InstallSnapshotStore.ets`。
- [ ] **Step 4: 跑测试确认通过** — Run: `node test/run-one.mjs InstallSnapshotStore.test.ets` → Expected: PASS 4/4；`node test/run.mjs` → Expected: 全绿。
- [ ] **Step 5: 记录产物/校验** — ledger 追加 `Task 5: complete (tests …)`。Expected: ledger 有该行。

---

### Task 6: `RefreshOrchestrator`（纯编排 + 唯一有效目录出口）

**Files:**
- Create: `entry/src/main/ets/form/RefreshOrchestrator.ets`
- Test: `entry/src/test/RefreshOrchestrator.test.ets`
- Modify: `test/run.mjs`（登记套件）

**Interfaces:**
- Consumes: Task 1–5 的全部产出 + `CapabilityRepository.fromItems` + `CardBinding.compose` + `CardFeedback`（TTL 在 compose 内）。
- Produces:
  ```ts
  export interface RefreshInput {
    l1: AtomicFunction[]; templates: AppTemplateEntry[]; probe: SchemeProbe;
    prev: InstallSnapshot; usage: UsageSnapshot; now: number;
    formId: string; failure: string; failureAt: number;
    dark: boolean; blurAvailable: boolean; appVersionFingerprint: string;
  }
  export interface RefreshResult {
    binding: CardBindingData; snapshot: InstallSnapshot;
    diff: CatalogDiffResult; effective: AtomicFunction[]; effectiveCount: number;
  }
  export class RefreshOrchestrator {
    static resolve(input: RefreshInput): RefreshResult;                    // 纯逻辑，零 SDK
    static effectiveRepository(context: common.Context): CapabilityRepository; // SDK 边界
  }
  ```
  `resolve` 9 步（顺序固定）：① `probed = InstalledProbe.installedIds(templates, probe)`；② `allIds = templates.filter(t => t.scheme!=='').map(t => t.id).sort()`；③ `versionChanged = input.appVersionFingerprint !== '' && input.appVersionFingerprint !== prev.appVersionFingerprint`；`snap0 = versionChanged ? CatalogDiff.resetDebounce(prev) : prev`；④ `snapshot = CatalogDiff.confirm(snap0, probed, allIds, now)`，并置 `snapshot.appVersionFingerprint = input.appVersionFingerprint`；⑤ `diff = CatalogDiff.diff(prev.installedIds, snapshot.installedIds)`；⑥ `effective = EffectiveCatalog.build(l1, templates, new Set(snapshot.installedIds))`；⑦ `repo = CapabilityRepository.fromItems(effective)`；⑧ `binding = CardBinding.compose(repo, usage, now, formId, failure, dark, blurAvailable, failureAt)` —— **原样透传** `failure/failureAt`，不重算不清空；⑨ 返回 `{binding, snapshot, diff, effective, effectiveCount}`。
  `effectiveRepository(context)`：从 `CapabilityRepository.fromContextSync(context).itemsSnapshot()` 取 L1、`AppTemplateCatalog.fromContextSync(context).entries()` 取模板、`InstallSnapshotStore.fromContextSync(context).load()` 取 prev、`new BundleSchemeProbe()`，以 `failure:'' / failureAt:0 / now:Date.now() / dark:false / blurAvailable:true / appVersionFingerprint:''` 调 `resolve`，`save(result.snapshot)`，返回 `CapabilityRepository.fromItems(result.effective)`。SDK 全部集中在此方法；`resolve` 保持纯函数可被 Node 直接驱动。
  **指纹口径钉死**：普通三方 HAP 拿不到 `getBundleInfo`（本 Spec §1），生产侧无法读取已安装 App 版本，故 `effectiveRepository` 与 `FormAbility.binding` 一律传 `appVersionFingerprint:''`（`versionChanged=false`，不触发重探）；`resetDebounce` 路径只由 Node 单测用变化的 fp 驱动，作为「将来能取到版本时的预留接口」。该口径记入 Task 6 ledger Ruling，不在文档里宣称已实现版本检测。

- [ ] **Step 1: 写失败测试** — 5 个 `it`（含 Review Focus #4）：
  ```ts
  it('resolve_preserves_active_failure_text_and_failureAt', 0, () => {   // Review Focus #4
    const r = RefreshOrchestrator.resolve(input({ failure:'『付款码』暂无可用直达入口', failureAt: 1000, now: 1000 }));
    expect(r.binding.failure).assertContain('暂无可用直达入口');
    expect(r.binding.failureAt).assertEqual(1000);
  });
  it('install_is_only_confirmed_on_the_second_consecutive_probe', 0, () => {
    let r = RefreshOrchestrator.resolve(input({ probe:true, now:1000 }));
    expect(r.effectiveCount).assertEqual(0);
    r = RefreshOrchestrator.resolve(input({ probe:true, now:2000, prev:r.snapshot }));
    expect(r.effectiveCount).assertEqual(1);
    expect(r.diff.added.join(',')).assertContain('tpl:alipay');
  });
  it('uninstall_removes_the_entry_after_two_false_probes', 0, () => { /* 对称 */ });
  it('version_fingerprint_change_resets_debounce', 0, () => { /* fp 'v1'→'v2' → streak 清空 */ });
  it('resolve_never_mutates_the_input_snapshot', 0, () => { /* prev.installedIds 不变 */ });
  ```
  `input()` 为测试内 helper：1 个 `tpl:alipay` 模板（scheme `'alipays'`，1 个 function）、空 L1、`fakeUsage()`、`nowMorning()` 系时间、`BundleSchemeProbe` 换成注入的假探针。
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs RefreshOrchestrator.test.ets` → Expected: FAIL（`ERR_MODULE_NOT_FOUND .../form/RefreshOrchestrator.ets`），exit 1。
- [ ] **Step 3: 最小实现** — 按 9 步 + `effectiveRepository` 写 `RefreshOrchestrator.ets`。
- [ ] **Step 4: 跑测试确认通过** — Run: `node test/run-one.mjs RefreshOrchestrator.test.ets` → Expected: PASS 5/5；`node test/run.mjs` → Expected: 全绿。
- [ ] **Step 5: 记录产物/校验** — ledger 追加两条 Ruling + 完成行：
  - `Task 6: Ruling: 本 Spec §3.2 把 formProvider 列在 RefreshOrchestrator，但为保持 resolve 纯函数可测，updateForm 仍留在 FormAbility.push / EntryAbility.pushCardResult — 职责等价、无 SDK 进入纯逻辑 — cost if wrong: 与 §3.2 表格文字有出入，行为一致`
  - `Task 6: Ruling: 生产侧 appVersionFingerprint 一律传 ''（普通 HAP 无法读版本），resetDebounce 仅由 Node 单测用变化 fp 驱动作预留接口 — 不在文档宣称已实现版本检测 — cost if wrong: 应用升级后 scheme 变化需等连续 2 次探测自然收敛`
  - `Task 6: complete (tests: node test/run.mjs → <N>/<N> PASS)`
  Expected: ledger 有这三行。

---

### Task 7: 运行时接线（Ability + 三个内页 + 刷新配置 + 回归）

**Files:**
- Modify: `entry/src/main/ets/form/FormAbility.ets:64-69, 83-106`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets:40-62, 101-149`
- Modify: `entry/src/main/ets/pages/AllFunctionsPage.ets:38-45`、`CategoryPage.ets:36-40`、`ConfigPage.ets`（若有 `fromContextSync`）
- Modify: `entry/src/main/resources/base/profile/form_config.json:11-13`
- Test: `entry/src/test/InstallAwareWiring.test.ets`（静态源码断言，仿 `InnerPageLayout.test.ets`）
- Modify: `entry/src/test/CardBinding.test.ets`（增删框回归，1 个 `it`）
- Modify: `test/run.mjs`（登记新套件）

**Interfaces:**
- Consumes: `RefreshOrchestrator.resolve` / `effectiveRepository`（Task 6）、`CardFeedback` / `CardBinding.compose`（既有）、`formProvider.updateForm` / `setFormNextRefreshTime`（既有）。
- Produces: 运行时行为：卡片与三个内页共用有效目录；`onAddForm` / `onUpdateForm` / `onFormEvent` / 页面拉起 / 直达结果 全部经有效目录重算；D2 失败 TTL 与 `push()` 定时器逻辑**保持原样**。

- [ ] **Step 1: 写失败测试** — `InstallAwareWiring.test.ets` 用**两个明确的 URL helper**（仿 `InnerPageLayout.test.ets`），6 个静态断言 `it`：
  ```ts
  const readMain = (rel: string) => readFileSync(
    new URL('../main/' + rel, import.meta.url), 'utf8');
  // 例：readMain('ets/form/FormAbility.ets') / readMain('resources/base/profile/form_config.json')
  it('form_ability_binding_goes_through_refresh_orchestrator', 0, () => {
    expect(readMain('ets/form/FormAbility.ets').includes('RefreshOrchestrator.resolve')).assertTrue();
  });
  it('entry_ability_push_and_launch_use_effective_repository', 0, () => {
    expect(readMain('ets/entryability/EntryAbility.ets').includes('RefreshOrchestrator.effectiveRepository')).assertTrue();
  });
  it('all_pages_use_effective_repository_not_raw_capabilities', 0, () => {   // Review Focus #5
    for (const f of ['AllFunctionsPage.ets','CategoryPage.ets','ConfigPage.ets']) {
      const s = readMain('ets/pages/' + f);
      expect(s.includes('RefreshOrchestrator.effectiveRepository')).assertTrue();
      expect(s.includes('CapabilityRepository.fromContextSync')).assertFalse();
    }
  });
  it('form_config_has_updateDuration_without_scheduledUpdateTime', 0, () => {
    const j = JSON.parse(readMain('resources/base/profile/form_config.json'));
    expect(j.forms[0].updateDuration).assertEqual(1);
    expect(j.forms[0].scheduledUpdateTime).assertUndefined();
  });
  it('D2_failure_timer_is_unchanged', 0, () => {
    expect(readMain('ets/form/FormAbility.ets').includes('setFormNextRefreshTime')).assertTrue();
  });
  it('card_ets_is_not_modified_by_this_round', 0, () => {
    const s = readMain('ets/form/WidgetCard.ets');
    expect(s.includes('InstalledProbe') || s.includes('AppTemplateCatalog') || s.includes('canOpenLink')).assertFalse();
  });
  ```
  并在 `CardBinding.test.ets` 追加：
  ```ts
  it('compose_rebuilds_frames_when_catalog_adds_or_removes_items', 0, () => {
    const a = CardBinding.compose(CapabilityRepository.fromItems(makeItems(8)), fakeUsage(), nowMorning(), '', '', false, true);
    const b = CardBinding.compose(CapabilityRepository.fromItems(makeItems(4)), fakeUsage(), nowMorning(), '', '', false, true);
    expect(a.frames[0].key === b.frames[0].key).assertFalse();
    expect(b.frames[0].key.includes('fn-0')).assertTrue();
  });
  ```
- [ ] **Step 2: 跑测试确认失败** — Run: `node test/run-one.mjs InstallAwareWiring.test.ets` → Expected: FAIL（静态断言为 false），exit 1。
- [ ] **Step 3: 接线 `FormAbility`** — `binding(formId, failure, failureAt)` 改为构造 `RefreshInput`（`l1` 取 `CapabilityRepository.fromContextSync(this.context).itemsSnapshot()`、`templates` 取 `AppTemplateCatalog.fromContextSync(this.context).entries()`、`prev` 取 `InstallSnapshotStore.fromContextSync(this.context).load()`、`probe` 取 `new BundleSchemeProbe()`），调 `RefreshOrchestrator.resolve(...)`，**保存** `result.snapshot`，返回 `result.binding`。`failure`/`failureAt` 原样透传（TTL 由 compose 判定）。`push()` 与四个 `on*` 回调**不改**。
- [ ] **Step 4: 接线 `EntryAbility`** — `pushCardResult` 与 `runLaunch` 的 `CapabilityRepository.fromContextSync` 改为 `RefreshOrchestrator.effectiveRepository`；`onNewWant` / `onWindowStageCreate` 在**非 launch** 页加载后调用 `this.pushCardResult('')`（`pushCardResult` 内部已有 formId 判空），实现本 Spec §6.1 优先级 1「打开内页即时刷新」。Expected: 不新增 `setFormNextRefreshTime` 调用。
- [ ] **Step 5: 接线三个内页** — `AllFunctionsPage.reload()` / `CategoryPage.reload()` / `ConfigPage`（如有）的 `CapabilityRepository.fromContextSync(getContext(this))` 改为 `RefreshOrchestrator.effectiveRepository(getContext(this))`；`listAll` / `listByCategory` 调用保持不变。
- [ ] **Step 6: 刷新配置** — `form_config.json` 删 `"scheduledUpdateTime": "10:30"`，保留 `"updateEnabled": true` 与 `"updateDuration": 1`（仅当 Task 0 `PERIODIC_REFRESH_OK=true`；否则 ledger 记 Ruling 并保留原状、如实报告）。
- [ ] **Step 7: 跑测试确认通过** — Run: `node test/run-one.mjs InstallAwareWiring.test.ets` → Expected: PASS 6/6；`node test/run.mjs` → Expected: 全绿（含 CardBinding 新增 1 条）。
- [ ] **Step 8: 真实 ArkTS 编译（全量）** — Run: `DEVECO_SDK_HOME=D:/Huawei/command-line-tools/sdk bash -lc "cd E:/CodeE/vibe51/Stargate && D:/Huawei/command-line-tools/hvigor/bin/hvigorw clean assembleHap --mode module -p product=default"` → Expected: `BUILD SUCCESSFUL`，`widgets.abc` 与 `modules.abc` 均生成，0 ArkTS 编译错误。若报 `arkts-no-untyped-obj-literals` / 结构类型错误 → 用 `systematic-debugging` 查根因后最小修复，重跑本步骤。
- [ ] **Step 9: 记录产物/校验** — ledger 追加 `Task 7: complete (tests …; hvigorw → BUILD SUCCESSFUL)` + 任何 Ruling。Expected: ledger 有该行。

---

### Task 8: 全量验收 / 真机截图 / 自包含 HTML 报告

**Files:**
- Create: `.superpowers/sdd/2026-11-08-harmony-atomic-function-panel-install-aware-sync-plan/evidence/`（截图 + layout dump）
- Create: `.superpowers/sdd/2026-11-08-harmony-atomic-function-panel-install-aware-sync-plan/install-aware-report.html`
- Create: `.superpowers/sdd/2026-11-08-harmony-atomic-function-panel-install-aware-sync-plan/script/build-install-aware-report.mjs` + `check-install-aware-report.mjs`
- Modify: `.superpowers/sdd/2026-11-08-harmony-atomic-function-panel-install-aware-sync-plan/progress.md`（ledger 收尾）

**Interfaces:**
- Consumes: 既有 `iterate-variant.mjs` / `capture-final-pages.mjs` / `sign-ctrl.mjs` / `check-precise-report.mjs` 的成熟链路；Task 0 `conclusions.md`；Task 7 编译产物。

- [ ] **Step 1: FRESH 全量单测** — Run: `node test/run.mjs` → Expected: 输出 `N tests / M suites / N pass / 0 fail`，exit 0（N = 94 + 本轮新增套件条数）。记录 N/M 实际值。
- [ ] **Step 2: FRESH 产品编译** — 重跑 Task 7 Step 8 的 `clean assembleHap` → Expected: `BUILD SUCCESSFUL`。
- [ ] **Step 3: 对照构建 + 离线签名 + 验签 + 装机** — 沿用 `iterate-variant.mjs` 的 `cpSync` 路径（保留对照 `com.example.minimal` 与 `TEST FIXTURE ONLY` fixture）构建 control HAP → `node script/sign-ctrl.mjs 12` → Expected: `verify-app success` → `hdc -t 5KPBB25927200695 install -r <hap>` → Expected: `install bundle successfully`。口令/token 只在内存，日志脱敏。
- [ ] **Step 4: 真机截图** — 用 `capture-final-pages.mjs` 的可靠导航（force-stop / `keyEvent Home` / 滑动 / 皮套对话框 dismiss）抓：首页卡片、全量页、搜索页、分类页、配置页，共 5 张 fresh `uitest screenCap` + `dumpLayout`。Expected: 5 张 PNG + 对应 dump 落盘；逐张记录 `CARD_OK` / 页面 marker。
- [ ] **Step 5: 逐项 S1–S6 诚实核对** — 对照本 Spec §0.2 六条，逐条写「已验证 / 受限于 X、未验证」及依据（dump 文本计数 + 截图）。**不夸大**：真实包名 `com.stargate.functionpanel` 装机仍被 AGC 401 阻塞；若 Task 0 未查得真实 scheme，则 S2/S3 只能由 Node 去抖测试 + 对照 fixture 证明，须明写。Expected: §0.2 六行全部有结论与依据。
- [ ] **Step 6: 生成自包含 HTML 报告** — `build-install-aware-report.mjs` 内嵌 5 张截图（base64 data URI）、Task 0 四项结论、S1–S6 表、两层目录 / 去抖 / 刷新配置说明、编译与单测证据、诚实边界。要求：0 外部资源、0 `<script>`、无密钥/口令/token 值。Expected: 生成 HTML。
- [ ] **Step 7: 报告程序化门禁** — Run: `node script/check-install-aware-report.mjs` → Expected: `REPORT_CHECK=PASS`（DOCTYPE、5 张 PNG 签名、0 外部引用、0 script、0 密钥标记、关键内容串齐全）。
- [ ] **Step 8: 记录产物/校验** — ledger 追加 `Task 8: complete (tests …; BUILD SUCCESSFUL; verify-app success; install bundle successfully; REPORT_CHECK=PASS)` + `Final review: self-review (no subagent tool)`（本轮无 subagent 全分支评审，弱于独立评审，须在最终消息说明）。Expected: ledger 有该行；SDD 工作区保留。

---

## Self-Review

**1. Spec coverage** — §0.2 S1–S6 → Task 8 Step 5；§1 平台边界 → Global Constraints + Task 0；§2 决策增量 → Task 1 Step 6 / Task 7 Step 9 ledger 的「决策变更记录」；§3 组件清单/数据流/两层模型 → Tasks 1–7；§4 模板清单与 `querySchemes` → Task 1 Step 4 + Task 2 Step 4；§5 探测/有效目录/diff/快照/去抖/卡片 key → Tasks 2–4、Task 7 Step 7 的 `CardBinding` 回归；§6 触发源/D2 解耦/`form_config` → Task 7 Steps 3–6；§7 错误处理 → Global Constraints + Task 2 / Task 5 测试；§8 Task 0 探针 / 单测 / 真机 → Task 0、Tasks 1–8；§9 风险 → 各 Ruling 与 Task 8 诚实边界。无未覆盖条款。

**2. Step scan** — 每步单一动作且可核对：测试步给出 `it` 名与断言值；实现步给出文件名 + 签名 + 钉死规则（仅 `CatalogDiff.confirm` 与 `RefreshOrchestrator.resolve` 给算法，因签名无法确定）；验证步给命令 + Expected；无「TBD / 适当处理 / 写上述测试」类空行。

**3. Type consistency** — `AppTemplateEntry` / `TemplateFunction` / `SchemeProbe` / `InstallSnapshot` / `CatalogDiffResult` / `RefreshInput` / `RefreshResult` 在 Produces 与后续 Consumes 中同名同形；`EffectiveCatalog.build(..., Set<string>)` 与 `RefreshOrchestrator` 的 `new Set(snapshot.installedIds)` 对齐；`CardBinding.compose(repo, usage, now, formId, failure, dark, blurAvailable, failureAt?)` 与既有签名逐参一致；`CapabilityRepository.fromItems` / `itemsSnapshot` 均为既有方法。

**4. Review Focus** — 5 条分别钉在 Task 3 / Task 2 / Task 4 / Task 6 / Task 7 的具体 `it` 中，均已写入对应任务的 Step 1。

**5. Proportion** — 本计划 529 行 / 9 个 Task / 55 个 checkbox，约为 383 行 Spec 的 1.4 倍；增量主要是各 Task 的 `Interfaces` 契约与测试断言代码块（这些正是执行者无法自行推断、必须钉死的部分）。未抄写任何产品实现体：只有 `CatalogDiff.confirm` 与 `RefreshOrchestrator.resolve` 给了伪代码级算法（签名本身无法确定），其余实现步只给文件名 + 签名 + 规则。比例合理，非「数倍转抄」。

**Self-review 补记（逐项核对后修正 3 处）：** ① Task 7 Step 1 的静态断言原用含糊的 `'../../main/...'` 相对路径 → 改为明确的 `readMain(rel)`（`new URL('../main/' + rel, import.meta.url)`，仿 `InnerPageLayout.test.ets`）；② `RefreshOrchestrator.resolve` 的 `versionChanged` 判定原写成自由参数「fp 变化」→ 钉死为 `input.appVersionFingerprint !== '' && !== prev.appVersionFingerprint`；③ 补「指纹口径」段，明确生产侧一律传 `''`（普通 HAP 无法读版本），`resetDebounce` 仅作单测预留接口，避免文档宣称未实现的版本检测。三处均已 inline 修入上述正文。
