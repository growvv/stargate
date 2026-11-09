# 能力面板形态 A 与 L0 过滤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把产品定位落地为「本设备可用能力 + 自有功能」：新增显式带参卡与 9 类官方垂类入口、给 `EffectiveCatalog` 加 L0 过滤，使未验证模板永不生成卡片。

**Architecture:** 数据层用 `AtomicFunction` 单条 `route` 承载六种来源；`vertical` 是唯一需要新分支的 kind，通过注入的 `VerticalStarter` 调用 `UIAbilityContext.startAbilityByType`。`EffectiveCatalog` 从「L1 + 模板合并」改为「只输出 L0」，安装快照/diff 逻辑保留。`capabilities.json` 是唯一可直接点击目录。

**Tech Stack:** HarmonyOS NEXT / ArkTS（Stage 模型）、`@kit.AbilityKit`、Node 26 `node:module` strip-type 测试加载器 + `@ohos/hypium` 风格 shim、`hdc`（本计划不触发真机装机）。

**Spec:** `docs/superpowers/specs/2026-11-08-capability-shape-a-l0-filter-design.md`

## Global Constraints

- 产品 Spec §7：单条最可靠路由，无 `routes[]`、无 `home` kind；失败固定 `ok=false, reason='NO_AVAILABLE_ENTRY'`，**不回退 App 首页**；运行时不做降级。
- 分类固定 9 类：`支付, 购物, 出行, 社交, 生活, 娱乐, 健康运动, 工具效率, 其他`。
- `compatibleSdkVersion: "5.0.0(12)"`、`targetSdkVersion: "5.0.5(17)"`；`startAbilityByType` 用 `@since 11` 的 **callback 四参重载**（与 A3 spike 已验证形状一致）。
- `capabilities.json` 是唯一可直接点击目录；`discovery-candidates.json` / `app_templates.json` 只作候选面。
- 不编造 scheme / 参数键名；未验证落点不宣称成功；不把高德参数表复制给别的 App。
- 不改既有 Spec 正文、不改技术预研 Spec、不执行 P7 实现计划、不碰 AGC 401 签名、不修 `explorer` 空白页。
- 无 git 仓库：**不建 git / 不 commit / 不 push**；每个 Task 结束时把「测试命令 + 输出 + 裁定」追加到 `.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/progress.md` 作为台账，替代 commit。
- TDD Iron Law：每个生产改动前先写失败测试并**看到它红**；全量套件 `node test/run.mjs` 必须 0 fail。
- 凭据/口令不进入任何文件；证据文件不写密钥。

## Review Focus

1. **外部可替换配置注入未验证条目**：D5 外部 `capabilities.json` 可被 `hdc push` 替换，攻击者或误操作可塞 `template/0.5` 条目 → `EffectiveCatalog` 必须过滤，不让它变成卡片。测试：Task 3 `non_L0_l1_entry_is_filtered_even_if_present`。
2. **模板已安装但仍未验证**：P7 双次确认后 `installedIds` 命中 → 不得注入 `template` 卡片，也不得隐藏同名 L0 条目。测试：Task 3 `installed_template_never_produces_card` / `L0_survives_installed_same_name_template`；Task 4 编排级复验。
3. **`vertical` 误走 `startAbility`**：若注入点缺省，垂类卡可能退化成带空 bundleName 的裸 Want 或打开首页 → 必须固定 `NO_AVAILABLE_ENTRY`，且不调用 `starter`。测试：Task 6 `vertical_failure_does_not_call_startAbility`。
4. **浮点参数被字符串化 / 截断**：`32.060844` 若变成 `"32.060844"` 或 `0`，高德算不出路线停在输入页（A3 已实测）→ 类型与透传都必须保住 number。测试：Task 1 `parameters_keep_number_precision`、Task 6 `s2_parameters_pass_through_with_float`。
5. **`startAbilityByType` 在前台之外 / 抛错 / `onError`**：任一失败路径都必须单层报告，不得重试或二次拉起。测试：Task 6 `vertical_throw_is_reported_once` / `vertical_callback_error_is_reported_once`。

---

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `entry/src/main/ets/model/AtomicFunction.ets` | 数据契约 | Modify：加 `vertical` kind、放宽 `parameters` 值类型、新增 `isL0()` |
| `entry/src/main/ets/data/CapabilityRepository.ets` | 能力库解析 | Modify：`ROUTE_KINDS` 放行 `vertical` |
| `entry/src/main/ets/data/AppTemplateCatalog.ets` | 模板候选解析 | Modify：`ROUTE_KINDS` 放行 `vertical` |
| `entry/src/main/ets/data/EffectiveCatalog.ets` | 有效目录 | Modify：改为只输出 L0，取消模板注入与 appName 隐藏 |
| `entry/src/main/ets/form/RefreshOrchestrator.ets` | 刷新编排 | 不改逻辑；仅被 Task 4 测试覆盖 |
| `entry/src/main/ets/launch/LaunchResult.ets` | 注入点契约 | Modify：新增 `VerticalStarter` 类型 |
| `entry/src/main/ets/launch/LaunchDispatcher.ets` | 直达分发 | Modify：加 `vertical` 分支、`verticalStarter` 第 4 参 |
| `entry/src/main/ets/launch/VerticalStarter.ets` | 生产侧 `startAbilityByType` 适配 | Create |
| `entry/src/main/ets/entryability/EntryAbility.ets` | UIAbility 直达 | Modify：注入 `VerticalStarter` |
| `entry/src/main/ets/pages/AllFunctionsPage.ets` | 全部功能页直达 | Modify：注入 `VerticalStarter` |
| `entry/src/main/ets/pages/CategoryPage.ets` | 分类页直达 | Modify：注入 `VerticalStarter` |
| `entry/src/main/resources/rawfile/capabilities.json` | 可直接点击目录 | Modify：4 → 14 条（+1 S2、+9 S3） |
| `entry/src/main/resources/rawfile/capabilities.README.md` | 种子说明 | Modify：L0 过滤 + 垂类待验标记 |
| `test/shims-sdk.mjs` | SDK 测试 shim | Modify：导出 `common` 命名空间（含 `UIAbilityContext` / `AbilityStartCallback`） |
| `entry/src/test/AtomicFunction.test.ets` | 模型测试 | Create |
| `entry/src/test/LaunchDispatcher.test.ets` | 分发测试 | Modify：追加 vertical / 参数透传用例 |
| `entry/src/test/CapabilityRepository.test.ets` | 解析测试 | Modify：追加 vertical kind 用例 |
| `entry/src/test/EffectiveCatalog.test.ets` | 目录测试 | Modify：改写为 L0 语义 |
| `entry/src/test/RefreshOrchestrator.test.ets` | 编排测试 | Modify：改写 effectiveCount 预期 + 追加不复活用例 |
| `entry/src/test/SeedCatalog.test.ets` | 种子数据测试 | Create |
| `entry/src/test/VerticalStarter.test.ets` | 生产适配测试 | Create |
| `test/run.mjs` | 套件注册 | Modify：注册 3 个新 suite |
| `progress.md` | 台账 | Modify：每 Task 追加记录 |

---

## Task 1: 数据契约 —— `vertical` kind、参数值类型、`isL0()`

**Files:**
- Modify: `entry/src/main/ets/model/AtomicFunction.ets`
- Create: `entry/src/test/AtomicFunction.test.ets`
- Modify: `test/run.mjs`
- Modify: `progress.md`

**Interfaces:**
- Produces: `export type RouteKind = 'want' | 'deeplink' | 'applinking' | 'shortcut-param' | 'vertical'`；`Route.parameters?: Record<string, string | number | boolean>`；`export function isL0(fn: AtomicFunction): boolean`；`L0_SOURCES: string[]`、`L0_MIN_CONFIDENCE: number = 0.85`（常量供 EffectiveCatalog 与测试引用）。
- `isL0` 规则（Spec §4.1）：`L0_SOURCES` = `['linkFeature','scheme','shortcut','manual']`，且 `typeof fn.confidence === 'number'` 且 `fn.confidence >= L0_MIN_CONFIDENCE`。其余 source（`template`/`rea`/`injection`）或缺失/越界 confidence 一律 false。

- [ ] **Step 1: 写失败测试** `entry/src/test/AtomicFunction.test.ets`

```ts
import { describe, it, expect } from '@ohos/hypium';
import { isL0, L0_MIN_CONFIDENCE } from '../main/ets/model/AtomicFunction';
import type { AtomicFunction, Route } from '../main/ets/model/AtomicFunction';
import { makeFunction } from './TestFixtures';

function withSource(source: string, confidence: number): AtomicFunction {
  const f = makeFunction({ kind: 'deeplink', uri: 'x://y' });
  f.source = source; f.confidence = confidence; return f;
}
export default function atomicFunctionTest() {
  describe('AtomicFunction', () => {
    it('L0_min_confidence_is_085', 0, () => { expect(L0_MIN_CONFIDENCE).assertEqual(0.85); });
    it('verified_sources_are_L0', 0, () => {
      expect(isL0(withSource('linkFeature', 0.95))).assertTrue();
      expect(isL0(withSource('scheme', 0.85))).assertTrue();
      expect(isL0(withSource('shortcut', 1.0))).assertTrue();
      expect(isL0(withSource('manual', 1.0))).assertTrue();
    });
    it('unverified_sources_are_not_L0', 0, () => {
      expect(isL0(withSource('template', 0.5))).assertFalse();
      expect(isL0(withSource('rea', 0.6))).assertFalse();
      expect(isL0(withSource('injection', 0.2))).assertFalse();
      expect(isL0(withSource('linkFeature', 0.84))).assertFalse();
    });
    it('parameters_keep_number_precision', 0, () => {
      const r: Route = { kind: 'deeplink', uri: 'systemnav://routeplan',
        parameters: { destinationLatitude: 32.060844, sceneType: 1, destinationName: '测试地点' } };
      const f = makeFunction(r);
      const p = f.route.parameters as Record<string, Object>;
      expect(typeof p['destinationLatitude']).assertEqual('number');
      expect(p['destinationLatitude']).assertEqual(32.060844);
      expect(p['sceneType']).assertEqual(1);
    });
    it('vertical_is_a_valid_route_kind', 0, () => {
      const f = makeFunction({ kind: 'vertical', parameters: { verticalType: 'navigation', sceneType: 1 } });
      expect(f.route.kind).assertEqual('vertical');
    });
  });
}
```

- [ ] **Step 2: 注册 suite 并看它红**

在 `test/run.mjs` 的 `suites` 数组追加 `'./AtomicFunction.test.ets'`。
Run: `node test/run-one.mjs AtomicFunction.test.ets`
Expected: FAIL（`isL0` / `L0_MIN_CONFIDENCE` 未导出；类型错误由 strip-type 不检查，故断言因 undefined 失败）。

- [ ] **Step 3: 实现** `entry/src/main/ets/model/AtomicFunction.ets`

按 Interfaces 的签名与值加入 `vertical`、`parameters` 联合类型、`L0_SOURCES` / `L0_MIN_CONFIDENCE` / `isL0()`。不改动 `CATEGORIES`、`SOURCE_CONFIDENCE` 现有键值。

- [ ] **Step 4: 看它绿**

Run: `node test/run-one.mjs AtomicFunction.test.ets`
Expected: `tests 5 / pass 5 / fail 0`

- [ ] **Step 5: 全量 + 台账**

Run: `node test/run.mjs`
Expected: `tests 128 / pass 128 / fail 0`（原 127 + 5 − 已在其它 suite 的重复计数以实际输出为准，**不得**为凑数删测试）
在 `progress.md` 追加 `=== 形态A Task1 ===` 段：命令、输出摘要、裁定「参数值类型放宽为 string|number|boolean；isL0 为纯函数」。

---

## Task 2: 解析层放行 `vertical`

**Files:**
- Modify: `entry/src/main/ets/data/CapabilityRepository.ets:33`
- Modify: `entry/src/main/ets/data/AppTemplateCatalog.ets:30`
- Modify: `entry/src/test/CapabilityRepository.test.ets`
- Modify: `entry/src/test/AppTemplateCatalog.test.ets`
- Modify: `progress.md`

**Interfaces:**
- Consumes: Task 1 的 `RouteKind`（含 `vertical`）。
- Produces: 两个 `ROUTE_KINDS` 常量各含 5 个值，`CapabilityRepository.parse()` 与 `AppTemplateCatalog.parse()` 接受 `vertical` 条目。

- [ ] **Step 1: 写失败测试**

`CapabilityRepository.test.ets` 追加：

```ts
it('parse_accepts_vertical_kind', 0, () => {
  const seed = JSON.stringify({ items: [
    { id: 'v', appName: '系统能力', label: '路线规划·选应用', category: '出行',
      bundleName: 'com.example.verticalhost', route: { kind: 'vertical', parameters: { verticalType: 'navigation', sceneType: 1 } },
      source: 'manual', confidence: 1 }
  ]});
  const parsed = CapabilityRepository.parse(seed);
  expect(parsed.length).assertEqual(1);
  expect(parsed[0].route.kind).assertEqual('vertical');
});
```

`AppTemplateCatalog.test.ets` 追加：

```ts
it('parse_accepts_vertical_template_route', 0, () => {
  const out = AppTemplateCatalog.parse(JSON.stringify({ templates: [
    { id: 'tpl:v', appName: '系统能力', bundleName: '', category: '出行', scheme: '',
      kind: 'system', verifiedByProbe: false,
      functions: [{ label: '垂类', route: { kind: 'vertical', parameters: { verticalType: 'mail', sceneType: 1 } } }] }
  ] }));
  expect(out.length).assertEqual(1);
  expect(out[0].functions[0].route.kind).assertEqual('vertical');
});
```

- [ ] **Step 2: 看它红**

Run: `node test/run-one.mjs CapabilityRepository.test.ets` 与 `node test/run-one.mjs AppTemplateCatalog.test.ets`
Expected: 两条新断言 FAIL（`parse` 过滤掉 `vertical` → length 0）。

- [ ] **Step 3: 实现**

两处 `ROUTE_KINDS` 数组各追加 `'vertical'`。不改其它校验规则。

- [ ] **Step 4: 看它绿**

Run: 同上两个命令
Expected: 两个 suite 各自 `fail 0`

- [ ] **Step 5: 全量 + 台账**

Run: `node test/run.mjs` → `fail 0`。`progress.md` 追加 `=== 形态A Task2 ===`：两处 ROUTE_KINDS 同步放行的裁定。

---

## Task 3: `EffectiveCatalog` 只输出 L0（用户拍板项）

**Files:**
- Modify: `entry/src/main/ets/data/EffectiveCatalog.ets`
- Modify: `entry/src/test/EffectiveCatalog.test.ets`
- Modify: `progress.md`

**Interfaces:**
- Consumes: Task 1 的 `isL0(fn)`。
- Produces: `EffectiveCatalog.build(l1: AtomicFunction[], templates: AppTemplateEntry[], installedIds: Set<string>): AtomicFunction[]` —— 返回 `l1.filter(isL0)` 后按 `id` 升序排序的数组；`templates` / `installedIds` 参数保留但不参与输出构造；不再 import `SOURCE_CONFIDENCE`。

- [ ] **Step 1: 改写测试** `entry/src/test/EffectiveCatalog.test.ets`

保留 `l1()` / `tpl()` 辅助函数，把 `l1()` 的 `source` 改为 `'scheme'`、`confidence` 改为 `0.85`（L0）；另加 `nonL0()` 造 `source:'template', confidence:0.5`。五个测试改为：

```ts
it('uninstalled_template_never_creates_a_card', 0, () => {
  expect(EffectiveCatalog.build([l1('fn-a','支付宝')], [tpl('tpl:alipay','支付宝','alipays')], new Set<string>()).length).assertEqual(1);
  expect(EffectiveCatalog.build([l1('fn-a','支付宝')], [tpl('tpl:alipay','支付宝','alipays')], new Set<string>())[0].id).assertEqual('fn-a');
});
it('installed_template_never_produces_card', 0, () => {
  const out = EffectiveCatalog.build([], [tpl('tpl:alipay','支付宝','alipays')], new Set(['tpl:alipay']));
  expect(out.length).assertEqual(0);
});
it('L0_survives_installed_same_name_template', 0, () => {
  const out = EffectiveCatalog.build([l1('fn-a','支付宝')], [tpl('tpl:alipay','支付宝','alipays')], new Set(['tpl:alipay']));
  expect(out.length).assertEqual(1);
  expect(out[0].id).assertEqual('fn-a');
});
it('non_L0_l1_entry_is_filtered_even_if_present', 0, () => {
  const out = EffectiveCatalog.build([nonL0('fn-t','微信')], [tpl('tpl:wechat','微信','weixin')], new Set(['tpl:wechat']));
  expect(out.length).assertEqual(0);
});
it('result_is_sorted_by_id', 0, () => {
  const out = EffectiveCatalog.build([l1('z','甲'), l1('a','乙')], [], new Set<string>());
  expect(out[0].id).assertEqual('a');
});
```

- [ ] **Step 2: 看它红**

Run: `node test/run-one.mjs EffectiveCatalog.test.ets`
Expected: 至少 4 条 FAIL（现状会注入 template 卡片 / 隐藏同名 L1 / 不过滤 nonL0）。

- [ ] **Step 3: 实现** `entry/src/main/ets/data/EffectiveCatalog.ets`

`build()` 改为：`return l1.filter(isL0).slice().sort((a,b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0)`。删除 `knownApps` / `probedApps` / `byId` / 模板遍历逻辑与 `SOURCE_CONFIDENCE` import；类注释同步说明「L0-only gate，模板只用于安装快照，不进卡片」。保留三个参数签名不变（`RefreshOrchestrator` 依赖）。

- [ ] **Step 4: 看它绿**

Run: `node test/run-one.mjs EffectiveCatalog.test.ets`
Expected: `tests 5 / pass 5 / fail 0`

- [ ] **Step 5: 全量 + 台账**

Run: `node test/run.mjs` → 关注 `RefreshOrchestrator.test.ets` 是否因 effectiveCount 变化而失败；若失败属**预期红**，记录到台账，由 Task 4 修正（不要在此 Task 偷改编排测试）。
`progress.md` 追加 `=== 形态A Task3 ===`：L0 过滤裁定、模板注入已移除、appName 隐藏已取消。

---

## Task 4: `RefreshOrchestrator` 编排级复验

**Files:**
- Modify: `entry/src/test/RefreshOrchestrator.test.ets`
- Modify: `progress.md`
- （`RefreshOrchestrator.ets` 逻辑不改）

**Interfaces:**
- Consumes: Task 3 的 `EffectiveCatalog.build` L0-only 行为。
- Produces: 5 条既有测试改为「L0 语义」预期，另加 2 条新测试；`RefreshInput` / `RefreshResult` 契约不变。

- [ ] **Step 1: 改写测试**

把 `input()` 的 `l1` 默认改为含 1 条 L0 条目（用 `makeFunction({kind:'deeplink',uri:'verified://x'})` 并把 `source='scheme'`、`confidence=0.85`、`id='verified-a'`）。逐条修正：

```ts
it('templates_never_change_effective_count_after_two_probes', 0, () => {
  let r = RefreshOrchestrator.resolve(input({ now: 1000 }));
  expect(r.effectiveCount).assertEqual(1);
  expect(r.effective[0].id).assertEqual('verified-a');
  r = RefreshOrchestrator.resolve(input({ now: 2000, prev: r.snapshot }));
  expect(r.effectiveCount).assertEqual(1);               // 模板双次确认也不注入
  expect(r.diff.added.join(',')).assertEqual('tpl:demo'); // 安装 diff 仍工作
});
it('uninstalled_template_never_removes_L0_entry', 0, () => {
  let r = RefreshOrchestrator.resolve(input({ now: 1000 }));
  r = RefreshOrchestrator.resolve(input({ now: 2000, prev: r.snapshot,
    probe: { canOpen: (_s: string) => false } }));
  r = RefreshOrchestrator.resolve(input({ now: 3000, prev: r.snapshot,
    probe: { canOpen: (_s: string) => false } }));
  expect(r.effectiveCount).assertEqual(1);
  expect(r.effective[0].id).assertEqual('verified-a');
});
it('effective_contains_only_L0_even_with_installed_template', 0, () => {
  const r = RefreshOrchestrator.resolve(input({ now: 1000 }));
  expect(r.effective.some((f) => f.source === 'template')).assertFalse();
});
```

其余三条（`preserves_failure_feedback_while_rebuilding_the_catalog` / `version_change_resets_debounce_before_confirmation` / `does_not_mutate_the_previous_snapshot`）保持原断言不变；如需调整只改 `input()` 默认值带来的影响，不改测试意图。

- [ ] **Step 2: 看它红/绿并记录**

Run: `node test/run-one.mjs RefreshOrchestrator.test.ets`
Expected: 若 Task 3 已使旧断言失效，此时应看到失败输出；Step 1 改写后应 `fail 0`。**必须实际跑一次改写前的红**（先跑旧文件，再改），把两次输出都写进台账。

- [ ] **Step 3: 确认生产文件无需改动**

读 `entry/src/main/ets/form/RefreshOrchestrator.ets:47-69`，确认 `EffectiveCatalog.build` 调用签名未变、`snapshot` / `diff` / `CardBinding` 契约未变。若无需改动，在台账写明「生产编排零改动」。

- [ ] **Step 4: 全量 + 台账**

Run: `node test/run.mjs` → `fail 0`。`progress.md` 追加 `=== 形态A Task4 ===`：`effectiveCount` 不再随模板安装数变化；安装快照/diff 保留（P7 语义未废）。

---

## Task 5: `vertical` 启动通道（注入点 + 生产适配）

**Files:**
- Modify: `entry/src/main/ets/launch/LaunchResult.ets`
- Create: `entry/src/main/ets/launch/VerticalStarter.ets`
- Create: `entry/src/test/VerticalStarter.test.ets`
- Modify: `entry/src/main/ets/launch/LaunchDispatcher.ets`
- Modify: `entry/src/test/LaunchDispatcher.test.ets`
- Modify: `test/shims-sdk.mjs`
- Modify: `test/run.mjs`
- Modify: `progress.md`

**Interfaces:**
- Consumes: Task 1 的 `vertical` kind。
- Produces:
  - `LaunchResult.ets`: `export type VerticalStarterFn = (type: string, wantParam: Record<string, Object>) => Promise<boolean>`（SDK-free，测试可注入替身）。
  - `LaunchDispatcher.launch(fn, starter?, usage?, verticalStarter?)`：第 4 参可选；`vertical` 分支只调 `verticalStarter`，不调 `starter`、不构造 Want。
  - `VerticalStarter.ets`: `export function createVerticalStarter(context: common.UIAbilityContext): VerticalStarterFn`，内部用 `common.AbilityStartCallback` + callback 四参重载调用 `context.startAbilityByType(type, wantParam, cb, (err) => resolve(!err))`；`onError` 置失败；用一次性 `settled` 标志保证 Promise 只 resolve 一次。

- [ ] **Step 1: 写分发失败测试** `entry/src/test/LaunchDispatcher.test.ets` 追加

```ts
function verticalFn(): AtomicFunction {
  const f = makeFunction({ kind: 'vertical', parameters: {
    verticalType: 'navigation', sceneType: 1,
    destinationLatitude: 32.060844, destinationName: '测试地点' } });
  return f;
}
it('vertical_uses_verticalStarter_not_startAbility', 0, async () => {
  let starterCalls = 0, verticalCalls = 0, seenType = '', seen: Record<string, Object> = {};
  const starter = async (_w: Object) => { starterCalls++; return true; };
  const vertical = async (type: string, p: Record<string, Object>) => {
    verticalCalls++; seenType = type; seen = p; return true;
  };
  const r = await LaunchDispatcher.launch(verticalFn(), starter, undefined, vertical);
  expect(r.ok).assertTrue();
  expect(starterCalls).assertEqual(0);
  expect(verticalCalls).assertEqual(1);
  expect(seenType).assertEqual('navigation');
  expect(seen['sceneType']).assertEqual(1);
  expect(seen['destinationLatitude']).assertEqual(32.060844);
  expect(seen['verticalType']).assertUndefined(); // 已作为 type 取出，不混进业务参数
});
it('vertical_without_starter_reports_failure_without_fallback', 0, async () => {
  let starterCalls = 0;
  const r = await LaunchDispatcher.launch(verticalFn(), async (_w: Object) => { starterCalls++; return true; });
  expect(r.ok).assertFalse();
  expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
  expect(starterCalls).assertEqual(0);
});
it('vertical_failure_does_not_call_startAbility', 0, async () => {
  let starterCalls = 0;
  const r = await LaunchDispatcher.launch(verticalFn(),
    async (_w: Object) => { starterCalls++; return true; },
    undefined, async (_t: string, _p: Record<string, Object>) => false);
  expect(r.ok).assertFalse();
  expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
  expect(starterCalls).assertEqual(0);
});
it('s2_parameters_pass_through_with_float', 0, async () => {
  let captured: Record<string, Object> = {};
  const fn = makeFunction({ kind: 'deeplink', uri: 'systemnav://routeplan',
    parameters: { destinationLatitude: 32.060844, sceneType: 1, destinationName: '测试地点' } });
  await LaunchDispatcher.launch(fn, async (w: Object) => { captured = w as Record<string, Object>; return true; });
  const p = captured['parameters'] as Record<string, Object>;
  expect(p['destinationLatitude']).assertEqual(32.060844);
  expect(typeof p['destinationLatitude']).assertEqual('number');
});
```

- [ ] **Step 2: 看它红**

Run: `node test/run-one.mjs LaunchDispatcher.test.ets`
Expected: 4 条新用例 FAIL（第 4 个参数不存在 / `vertical` 落进 `want` 分支 / `parameters` 未被放进 want）。

- [ ] **Step 3: 实现 `VerticalStarterFn` 与 `LaunchDispatcher`**

`LaunchResult.ets` 追加 `VerticalStarterFn` 类型。`LaunchDispatcher.launch` 加第 4 参；在 `buildWant` 之前判断 `fn.route.kind === 'vertical'`：取 `parameters['verticalType']` 为 `type`（非 string 或空 → 直接返回 `NO_AVAILABLE_ENTRY`），其余键原样组成 `wantParam`（保留 `sceneType`），调 `verticalStarter`（无则 false），`ok` 时照常 `usage.record`，返回统一结果。`buildWant` 保持不变（四种既有 kind）。

- [ ] **Step 4: 补 shim 并写生产适配测试**

- `test/shims-sdk.mjs` 追加导出 `common`（命名空间对象，含 `UIAbilityContext`、`AbilityStartCallback` 的空类型占位或运行时 no-op 类），使 `@kit.AbilityKit` 的 `import { common }` 在 Node 测试里可解析；`test/loader.mjs` 的 `SHIMS` 增加 `'@kit.AbilityKit': new URL('./shims-sdk.mjs', import.meta.url).href`。
- 新建 `entry/src/test/VerticalStarter.test.ets`：

```ts
it('success_resolves_true_with_type_and_wantParam', 0, async () => {
  const calls: Object[] = [];
  const ctx = { startAbilityByType: (type: string, p: Record<string, Object>, _cb: Object, cb: (e?: Object) => void) => {
    calls.push({ type, p }); cb(); } };
  const start = createVerticalStarter(ctx as unknown as common.UIAbilityContext);
  expect(await start('navigation', { sceneType: 1 })).assertTrue();
  expect((calls[0] as Record<string, Object>)['type']).assertEqual('navigation');
});
it('callback_error_resolves_false', 0, async () => {
  const ctx = { startAbilityByType: (_t: string, _p: Object, _cb: Object, cb: (e?: Object) => void) => cb({ code: 16000050 }) };
  expect(await createVerticalStarter(ctx as unknown as common.UIAbilityContext)('mail', {})).assertFalse();
});
it('onError_resolves_false_and_throw_never_leaks', 0, async () => {
  const ctx = { startAbilityByType: (_t: string, _p: Object, cb: Object, _done: (e?: Object) => void) => {
    (cb as { onError: (c: number, n: string, m: string) => void }).onError(16000050, 'E', 'internal'); } };
  expect(await createVerticalStarter(ctx as unknown as common.UIAbilityContext)('mail', {})).assertFalse();
  const boom = { startAbilityByType: () => { throw new Error('boom'); } };
  expect(await createVerticalStarter(boom as unknown as common.UIAbilityContext)('mail', {})).assertFalse();
});
```

按 shim 实际形态调整 `common.UIAbilityContext` 的写法（若 ArkTS 类型在 Node 下不可用，改用结构类型断言，不改生产签名）。注册 `'./VerticalStarter.test.ets'` 到 `test/run.mjs`。

- [ ] **Step 5: 实现 `entry/src/main/ets/launch/VerticalStarter.ets`**

按 Interfaces 的签名与算法实现：`import { common } from '@kit.AbilityKit'`；构造 `const cb: common.AbilityStartCallback = { onError: (...) => { ... }, onResult: (...) => {} }`；`try { context.startAbilityByType(type, wantParam, cb, (err) => settle(!err)) } catch { settle(false) }`；`settle` 用 `settled` 布尔防重复 resolve。`onResult` 不视为成功（成功只由 callback err 决定）。

- [ ] **Step 6: 看它绿**

Run: `node test/run-one.mjs LaunchDispatcher.test.ets` 与 `node test/run-one.mjs VerticalStarter.test.ets`
Expected: 两个 suite `fail 0`（LaunchDispatcher 共 8 条、VerticalStarter 3 条）。

- [ ] **Step 7: 三个 UI 调用点注入**

`EntryAbility.ets:134` 前、`AllFunctionsPage.ets:58` 前、`CategoryPage.ets:53` 前各加一行：
`const verticalStarter = createVerticalStarter(ctx);`
并把 `LaunchDispatcher.launch(fn, starter, this.buildUsage())` 改为 `LaunchDispatcher.launch(fn, starter, this.buildUsage(), verticalStarter)`（共 3 处）。不改其它行为。

- [ ] **Step 8: 全量 + 台账**

Run: `node test/run.mjs` → `fail 0`。
`progress.md` 追加 `=== 形态A Task5 ===`：裁定「vertical 不构造 Want、不回退 startAbility；callback 四参重载（API 11）；三个 UI 调用点统一注入」。

---

## Task 6: 种子数据 14 条 + README + 数据验收

**Files:**
- Modify: `entry/src/main/resources/rawfile/capabilities.json`
- Modify: `entry/src/main/resources/rawfile/capabilities.README.md`
- Create: `entry/src/test/SeedCatalog.test.ets`
- Modify: `test/run.mjs`
- Modify: `progress.md`

**Interfaces:**
- Consumes: Task 1 `isL0()`、Task 2 `CapabilityRepository.parse()`。
- Produces: `capabilities.json` 顶层 `{ "_comment": ..., "items": [ 14 条 ] }`；`SeedCatalog.test.ets` 用 `node:fs` 读文件、`JSON.parse`、`CapabilityRepository.parse()` 校验。

- [ ] **Step 1: 写失败测试** `entry/src/test/SeedCatalog.test.ets`

```ts
import { describe, it, expect } from '@ohos/hypium';
import { readFileSync } from 'node:fs';
import { CapabilityRepository } from '../main/ets/data/CapabilityRepository';
import { isL0 } from '../main/ets/model/AtomicFunction';
import { CATEGORIES } from '../main/ets/model/AtomicFunction';

const PATH = 'entry/src/main/resources/rawfile/capabilities.json';
function seed(): { items: Array<Record<string, Object>> } {
  return JSON.parse(readFileSync(PATH, 'utf8'));
}
export default function seedCatalogTest() {
  describe('SeedCatalog', () => {
    it('has_14_items_all_parseable', 0, () => {
      const raw = readFileSync(PATH, 'utf8');
      expect(CapabilityRepository.parse(raw).length).assertEqual(14);
    });
    it('keeps_the_four_verified_L0_routes', 0, () => {
      const ids = seed().items.map((i) => i['id']);
      for (const id of ['real-amap-route','real-jd-storage','real-weibo-storage','real-quark-qianwen'])
        expect(ids.indexOf(id) >= 0).assertTrue();
    });
    it('explicit_amap_card_keeps_float_parameters', 0, () => {
      const f = seed().items.find((i) => i['id'] === 'explicit-amap-routeplan') as Record<string, Object>;
      const route = f['route'] as Record<string, Object>;
      const p = route['parameters'] as Record<string, Object>;
      expect(route['uri']).assertEqual('systemnav://routeplan');
      expect(p['destinationLatitude']).assertEqual(32.060844);
      expect(p['destinationLongitude']).assertEqual(118.78315);
      expect(p['destinationName']).assertEqual('测试地点');
    });
    it('nine_vertical_cards_use_official_type_scene_pairs', 0, () => {
      const vs = seed().items.filter((i) => (i['route'] as Record<string, Object>)['kind'] === 'vertical');
      expect(vs.length).assertEqual(9);
      const pairs = vs.map((v) => {
        const p = (v['route'] as Record<string, Object>)['parameters'] as Record<string, Object>;
        return p['verticalType'] + '/' + p['sceneType'];
      }).sort().join(',');
      expect(pairs).assertEqual('express/1,finance/1,finance/2,flight/1,flight/2,mail/1,navigation/1,navigation/2,navigation/3');
    });
    it('all_items_have_legal_category_and_are_L0', 0, () => {
      const parsed = CapabilityRepository.parse(readFileSync(PATH, 'utf8'));
      for (const f of parsed) {
        expect(CATEGORIES.indexOf(f.category) >= 0).assertTrue();
        expect(isL0(f)).assertTrue();
      }
    });
    it('no_fabricated_uri_outside_official_declarations', 0, () => {
      const allowed = ['systemnav://routeplan','storage://developer.huawei.com/clearcache',
        'sinaweibo://settings/cache','https://m.sm.cn/'];
      for (const i of seed().items) {
        const r = i['route'] as Record<string, Object>;
        if (r['uri'] !== undefined) expect(allowed.indexOf(r['uri'] as string) >= 0).assertTrue();
      }
    });
  });
}
```

注册 `'./SeedCatalog.test.ets'` 到 `test/run.mjs`。

- [ ] **Step 2: 看它红**

Run: `node test/run-one.mjs SeedCatalog.test.ets`
Expected: FAIL（`has_14_items_all_parseable` 得到 4；其余新增卡断言失败）。

- [ ] **Step 3: 写 `capabilities.json`（14 条）**

保留现有 4 条原样，新增 Spec §5.2 的 1 条 `explicit-amap-routeplan`（`source:'linkFeature'`, `confidence:0.95`, `category:'出行'`，parameters 五个键含 2 个浮点）与 Spec §5.3 的 9 条 `vertical`（`appName:'系统能力'`, `bundleName:'com.stargate.functionpanel'`, `source:'manual'`, `confidence:1`, `route:{kind:'vertical', parameters:{verticalType, sceneType}}`；navigation/1、/2、/3 额外带 `destinationLatitude:32.060844` / `destinationLongitude:118.78315` / `destinationName:'测试地点'`，其余五条**不**带业务参数）。`label` 用 Spec §5.3 表中值。`_comment` 更新为说明「L0 过滤 + 垂类入口；五条垂类真机落点待验」。

- [ ] **Step 4: 看它绿**

Run: `node test/run-one.mjs SeedCatalog.test.ets`
Expected: `tests 6 / pass 6 / fail 0`

- [ ] **Step 5: 更新 README**

`capabilities.README.md` 追加：① L0 过滤定义与 `EffectiveCatalog` 新语义；② `vertical` kind 与 `startAbilityByType` 说明；③ 9 条垂类中 4 条真机面板已验、5 条「官方映射，真机落点待验」的显式标记；④ 参数键名逐 App 确认、禁止复制高德参数表；⑤ 浮点参数不可字符串化。

- [ ] **Step 6: 全量 + 台账**

Run: `node test/run.mjs` → `fail 0`。
`progress.md` 追加 `=== 形态A Task6 ===`：14 条构成、待验标记、README 同步、裁定「S2 参数只写已验证的高德键名」。

---

## Task 7: 收尾验收

**Files:**
- Modify: `progress.md`
- Read-only: 全部 Spec / plan / 产品源码 mtime、`node test/run.mjs`、`node test/run-one.mjs <新 suite>` ×3

**Interfaces:**
- Consumes: Task 1–6 全部产出。

- [ ] **Step 1: 全量测试（fresh）**

Run: `node test/run.mjs`
Expected: `fail 0`、`cancelled 0`、`skipped 0`；记录实际 `tests` / `suites` / `pass` 数字，不引用旧数字。

- [ ] **Step 2: 逐条核对 Spec §8 验收标准**

在台账列 6 行检查表，逐行写 PASS/FAIL 依据：全绿且新测试先红后绿 / 14 条可 parse / EffectiveCatalog 只含 L0 且 effectiveCount 不随模板变 / vertical 不调 startAbility / 未改既有 Spec 与预研 Spec、未重建 HAP、未碰 AGC、无 git / README 与台账已更新。

- [ ] **Step 3: 边界复核**

只读检查：4 份既有 Spec + 4 份 plan 的 mtime 未变；`entry/src/main/ets` 改动文件清单与上表一致；无 `TypeLaunchProbe` 残留；无 token/口令进入文件；`discovery-candidates.json` 未被改动。

- [ ] **Step 4: 台账收尾 + 最终报告**

`progress.md` 追加 `=== 形态A 完成 ===`：`Rulings I made` 与 `Deferred minors`（`explorer` 空白、百度/花瓣落点、5 条垂类落点、AGC 签名、P7 其余任务、L2 矩阵）。向用户报告：改了什么、测试结果、哪些仍未验证、哪些按指示没碰。

---

## Self-Review（写入时已完成）

1. **Spec coverage**：§1 目标 → Task 1/3/5/6；§2 定位 → Task 3/6（README）；§3.1 类型 → Task 1；§3.2 六来源 → Task 1/5/6；§3.3 SDK 契约 → Task 5；§3.4 失败语义 → Task 5；§4 L0 过滤 → Task 1/3/4；§5 清单 → Task 6；§6 边界 → Task 1/3/5/6 测试 + Task 7；§7 测试策略 → 各 Task；§8 验收 → Task 7；§9 开放项 → Task 7 Deferred minors。无缺口。
2. **Step scan**：每步是可检查的单一动作；代码步只给签名、值与算法要点，未抄整段实现。
3. **Type consistency**：`isL0` / `L0_MIN_CONFIDENCE` / `VerticalStarterFn` / `createVerticalStarter` / `launch(fn, starter?, usage?, verticalStarter?)` 在 Task 1、3、5、6、7 中名称与形状一致；`EffectiveCatalog.build` 三参签名保持不变。
4. **Review Focus**：5 条输入类各有对应测试（见各条括号），已分配到 Task 1/3/5/6。
5. **Proportion**：计划 7 个 Task、约 30 步，短于 Spec 的实现细节总量；测试代码是唯一大段代码块（TDD 要求给出精确断言）。
