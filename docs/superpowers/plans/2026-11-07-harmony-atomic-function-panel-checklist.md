# 鸿蒙功能聚合面板 · 第一期交付校验表（2026-11-07）

> 依据：`docs/superpowers/plans/2026-11-07-harmony-atomic-function-panel-product-plan.md`
> Task 6 Step 7。每项为**实测/实查结果**，未做到的如实标注，不谎报。

## 一、工程与测试

| # | 校验项 | 结果 | 证据 |
|---|---|---|---|
| ① | 工程文件齐备（Stage 模型 HAP、module.json5、4×4 form_config、rawfile 种子、ArkTS 源码 20 个） | ✅ | `hvigorw clean assembleHap` BUILD SUCCESSFUL；HAP 含 module.json / form_config.json / main_pages.json / capabilities.json / modules.abc / widgets.abc |
| ② | 本地单测全绿 | ✅ **39/39 PASS**（37 项交付态 + 真机验证后追加 2 项） | 交付时 `node test/run.mjs` → tests 37 / pass 37 / fail 0 / exit 0；真机签名/截图验证发现两处缺陷后追加 `router_action_carries_top_level_ability_name`、`new_want_to_page_requires_content_reload` 两项 RED→GREEN，fresh `node test/run.mjs` → **39 / 39 / 0 / exit 0**（`evidence/final-test-after-signing-fix.log`）；`List.test.ets` 同步注册全部 14 套件 |
| ③ | 4×4 卡片可安装渲染 | ✅ **真机安装 + 桌面渲染已完成（对照构建）** / ⚠️ 产品真实包名安装被阻塞 | 用 JBR 21.0.8 + StarStack 缓存华为调试材料离线 `sign-app` / `verify-app` 成功；对照构建（仅 `AppScope/app.json5` 包名对齐缓存 profile 的 `com.example.minimal`）`hdc install` → `install bundle successfully`；系统「服务卡片」搜索「功能面板」→ 添加到桌面 → 目视 4×4 渲染，19 张真机截图见 §七。产品真实包名 `com.stargate.functionpanel` 仍被 `code:9568329` 拒绝（profile 绑定另一包名，AGC token 401 无法现场换发），如实保留 |
| ④ | 分类页 / 全量页 / 配置或引导配置均可达 | ✅ **真机往返已验证（并修复两处缺陷）** | `main_pages.json` 注册 4 页；`EntryAbility.applyWant` 对 formConfigAbility 无 page 的 Want 走 `ConfigAccess.pageForFormConfig('')='config'`。真机：点「⋯ 更多」→ AllFunctionsPage FOREGROUND（截图 14）；冷/热态点「配置」→ ConfigPage（截图 16/17/18）。修复前两处均为静默不跳转（截图 11/12/15），根因与 TDD 修复见 §七 |

## 二、产品硬约束（§7）

| # | 校验项 | 结果 | 证据 |
|---|---|---|---|
| ⑤ | 直达成功与失败两路径：无 home 回退、无多路由降级 | ✅ | `LaunchDispatcher` 单次 Want、失败 `NO_AVAILABLE_ENTRY`；`LaunchDispatcher.test.ets` 4 项（含 `no_second_route_attempt_on_failure` + 评审后 `want_is_explicit_with_target_bundle_name`）；去注释扫描无 `routes[]`/`home`/`isPinned`；`module.json5` 无 `entity.system.home`。评审后 I2：卡片侧直达失败经 `CardBinding.failure` 显示「暂无可用直达入口」（此前仅 console.error，已修） |
| ⑥ | 建议区最多 8 格自动排序、不足按实际（B2′）、只由用量驱动 | ✅ | `RankingEngine` / `WidgetCardData` / `SuggestionPolicy` 共 9 项测试：冷启动≤8、少量按实际、空库 0、高频置顶、用量变化即改变、无 pinned 可固定 |
| ⑦ | 毛玻璃或退化视觉、暗色模式可用 | ✅（逻辑层） | `ThemeTokens.build(blurAvailable, dark)` 取 `IOS_VISUAL_SPEC` 定稿；`ThemeTokens.test.ets` 2 项：blur 不可用时 `blur=''` 且渐变仍在、暗色独立配色。真机目视效果因③未做 |
| ⑧ | 技术预研 Spec 未修改 | ✅ | 429 行，`IOS_`/`Stage −1` 命中 0 |
| ⑧b | 预研收尾计划仅头部加「已并入，不单独执行」状态注记、正文未改（C2） | ✅ | 头部 C2 状态注记存在，任务正文保留 |
| ⑨ | 未执行任何 `git` 命令、未 `git init` | ✅ | 项目非 git 仓库；全程手工 SDD workspace + ledger |
| ⑩ | Task 0 throwaway 探针未并入产品工程 | ✅ | `probe/card_probe/` 独立于 `entry/`；产品 HAP 无探针代码 |
| ⑪ | uitest 扩展仅用于自有 HAP 的测试态验证，未进运行时、未针对真实第三方 App 模拟点击 | ✅ | 本轮 `uitest` 仅用于 `dumpLayout`/`screenCap`/按键清弹窗；未对第三方 App 深层页面实施模拟点击/注入 |

## 三、Stage −1 与三批拍板

| # | 校验项 | 结果 | 证据 |
|---|---|---|---|
| ⑫ | Stage −1（iOS 范式取证 → 设计定稿）完成并经（/goal 委托的）终审 | ✅ | `docs/research/ios-paradigm-reverse.md` 四证据表；`…ios-aligned-design.md` 四组 `IOS_*_SPEC` + B3 三栏 + [S]/[I] + 范式对齐层级；§5/§6.2/分类/§6.1 拼音已回填；三条硬约束原文未变；终审在 /goal 下自主裁决（ledger Ruling） |
| ⑬ | 第一批 5 项（Task 0 四探针含 EVENT_CHAIN/CARD_ADD_PATH、A2 点击即重排+定时兜底、A3 实测条目、B1 无收藏、C2 并入） | ✅ / ⚠️ A3 | Task 0 四结论写入 `probe/card_feasibility.md`；A2 `onUpdateForm`+`onFormEvent` 重排、`form_config` updateDuration=1；B1 无收藏/置顶；C2 头部注记。**A3：真机 `aa start` 落点未证实原子页（见 `probe/aa_start_landing_probe.md`），故能力库保持空种子 `{items:[]}`，未回填任何未验证 URI** |
| ⑭ | 第二批 7 项（B2 无推荐开关、B3 三维度有据终审、D1 内部自用、D2 第三方图标登记、D3 拼音按 `IOS_PINYIN_SPEC`、D4 用量不可见不可清空、D5 本地可替换配置） | ✅（D5 评审后修复） | ConfigPage 无推荐开关；B3 见⑫；D1 不上架；D2 代码未引用第三方图标资源（内部自用）；D3 PinyinUtil 离线表；D4 UsageStore 无查看/清空入口；**D5 经评审 C1 修复后不再是死代码**：`fromContextSync` 被 FormAbility/EntryAbility/CategoryPage/AllFunctionsPage 四处真实调用，外部可替换路径 + rawfile 种子（UTF-8 正确解码）+ 配置边界校验（拒 home kind/非法类目）全部生效，符号实测在 `modules.abc`。详见「六、评审后单趟修复」 |
| ⑮ | 第三批 3 项（B1′ CARD_ADD_PATH 有结论、B2′ 全库=已验证条目且建议区不足 8 按实际含 appName、B3′ 最小配置且分类增删改留待重估） | ✅ | B1′ 结论 `dev-install-only`；B2′ `AtomicFunction.appName` + ≤8 不凑数 + `SearchFilter` 用 appName 不用 bundleName；B3′ `CatalogEditor` 仅 `reorderCategory`、ConfigPage 仅排序+能力库替换入口 |

## 四、未达成 / 需明早人工确认（如实报告，2026-11-07 真机验证后更新）

> 2026-11-07 追加：原 ①/③/④ 的「真机安装阻塞」已被本轮离线签名 + 对照构建真机安装解开，详见 §七。以下仅保留**仍未达成**的项。

1. **产品真实包名 `com.stargate.functionpanel` 的现场安装**：仍被 `code:9568329` 阻塞。根因已钉死（缓存华为 profile 绑定 `com.example.minimal`，A/B 对照实验），而非证书链 / API level / 设备。为真实包名换发新 profile 需交互重新登录华为账号；缓存 AGC accessToken 已过期（HTTP 401，凭据库无 refresh token），无头会话无法续期。本轮用对照构建（仅包名不同）完成了全部真机验证。**明早人工一步**：在 StarStack / DevEco 里重新登录华为账号 → 自动签名为 `com.stargate.functionpanel` 申请新调试 profile → 安装真实包名 HAP。本轮未创建任何 AGC 资源、未做交互登录。
2. **真机端到端直达**：`aa start` 候选 URI 未证实命中原子功能页（`aa dump -l` 仅 `EntryAbility` 首页、截图为系统弹窗/黑屏）。需在 GUI 下逐条 force-stop→`aa start`→目视落点→截图，**只把确认命中原子页的 URI 回填 `capabilities.json`**（A3）。当前能力库为空种子 `{items:[]}`，卡片显示引导态，符合「失败不回退、如实报告」的产品立场。
3. **A–Z 索引条真机点击 / 分类 chip 往返**：代码层可达（`scrollToItemInGroup` 编译进 `modules.abc`），但空能力库下无可点条目，真机点击往返未单独取图。
4. **暗色模式 / 毛玻璃退化目视**：亮色渐变 4×4 卡片已真机目视（截图 10）；暗色与 blur 退化仅逻辑层单测覆盖，未单独取真机图。
5. **`SYSTEM_EDIT_ENTRY=false` 下的配置入口**：按 B3′ 不做桌面长按自定义配置（Task 0 结论）。配置页已由卡片空态「配置」按钮 / `formConfigAbility` 拉起，**真机已验证可达**（截图 16/17/18）。桌面长按仍交给系统「编辑桌面」处理（截图 05）。

## 五、评审后单趟修复（fresh reviewer 全量终审 → 一趟 TDD 修复）

`/goal` 授权自主决策。fresh reviewer（general-purpose / opus，读全部 production `.ets` + 计划/Spec/ledger/probe，
自行复跑 26/26）给出 C1（Critical）、I1–I7（Important）、M1–M7（Minor）、15 条 Declined to judge。
按 executing-plans「按 effect 重新定级 → Critical/Important 单趟修复 → Minor 延后」处理：

| 编号 | 级别 | 修复 | 覆盖测试（RED→GREEN） |
|---|---|---|---|
| C1 | Critical | 加 `CapabilityRepository.fromContextSync(context)`；FormAbility / EntryAbility / CategoryPage / AllFunctionsPage 四处改用它（真实 D5 能力库，不再 `fromItems([])`） | `from_context_sync_reads_rawfile_seed`、`CardBinding.compose_reads_real_catalog_for_runtime_consumers` |
| 自发现 Gap 2 | Important | `decodeUtf8` 替换逐字节 Latin-1 解码，中文种子不再乱码 | `decode_utf8_seed_preserves_chinese_labels` |
| I1 | Important | 所有 Route.kind 的 Want 显式带 `bundleName`；`parse` 拒 home kind/非法类目/非法 confidence（M1 并入） | `want_is_explicit_with_target_bundle_name`、`parse_rejects_invalid_route_kind_and_category` |
| I2 | Important | 卡片直达失败经 `CardBinding.failure` + `formProvider.updateForm` 显示「暂无可用直达入口」+ 失效小圆点 | `CardBinding.compose_includes_form_id_and_failure_for_visible_feedback` |
| I3 | Important | `UsageStore.withPreferencesSync` + `record()` 写回 `putSync/flushSync`；四处消费者共享；成功后 `updateForm` 重排 | `record_persists_via_sync_preferences_and_reloads` |
| I4 | Important | 冷启动时段先验（上午出行/晚间购物）注入 `W_HOUR*hourAffinity`，公式权重不变 | `cold_start_hour_prior_changes_category_order` |
| I5 | Important | `PageRouter.configParams()` + 卡片空态「配置」按钮 + `ConfigAccess.pageForFormConfig('')='config'`（修死入口） | `config_params_carry_page_config`、`form_config_want_opens_config_page_not_dead_index` |
| I6 | Important | A–Z 索引 `Text.onClick → ListScroller.scrollToItemInGroup` | （ArkTS 编译 + `modules.abc` 符号实测） |
| I7 | Important | `CardBinding` 解析 `ThemeTokens.build(dark, blurAvailable)`；WidgetCard 消费 `@LocalStorageProp` 主题字段，`backdropBlur(blurRadius)` 条件生效 | `compose_resolves_dark_and_blur_degraded_theme` |
| M5/M6 | Minor（顺带修） | README `firstAddGuideEnabled(true)` 笔误改 `false`；本表 ④/⑤/⑭/② 修正为如实表述 | — |

- **全绿证据**：`node test/run.mjs` → 37/37 PASS exit 0；`hvigorw clean assembleHap` → BUILD SUCCESSFUL exit 0（首次编译 9 个 ArkTS 错误经 systematic-debugging 定位为 `arkts-no-structural-typing`，改用 SDK 真实 `preferences.Preferences` 类型修复）。
- **符号实测**：`fromContextSync`/`decodeUtf8`/`withPreferencesSync`/`pageForFormConfig`/`configParams`/`CardBinding`/`pushCardResult`/`scrollToItemInGroup` 在 `modules.abc`；`configParams`/`failure`/`formId`/`gradientDark`/`blurRadius`/`ConfigPage` 在 `widgets.abc`。
- **延后 Minor**：M2（Want 用 SDK 类型而非 Object）、M3（第三方 App 图标）、M4（上滑关闭）、M7（seqBoost 用全量序列）按门控不进修复趟，见交接「Deferred minors」。
- **Declined to judge 15 条**：逐条按 `Final: Ruling:` 裁决写入 ledger（保持现状，均为计划明确移出/平台禁止/工具链阻塞的如实延后）。
- **A3 诚实性保留**：`capabilities.json` 仍为空种子 `{items:[]}`，未回填任何未验证 URI；评审明确肯定这一点，修复未以「凑数」换取通过。

## 六、命令速查

```bash
# 本地单测（Node 26 strip-types runner，非 hvigorw：本机 hvigorw 无本地单测任务）
node test/run.mjs                 # 全量 39 项（真机验证后）
node test/run-one.mjs <Suite.test.ets>   # 需完整文件名，如 PageRouter.test.ets

# 真实 ArkTS 编译（需 DEVECO_SDK_HOME）
DEVECO_SDK_HOME=D:/Huawei/command-line-tools/sdk \
  /d/Huawei/command-line-tools/hvigor/bin/hvigorw clean assembleHap --mode module -p product=default
```

## 七、真机签名与截图验证追加（2026-11-07，用户要求 StarStack 签名 → 截图 → HTML 报告）

> **交付物**：自包含 HTML 报告（19 张真机截图 base64 内嵌，无外链加载、无密钥明文）
> `.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/verify-signing/screenshot-validation-report.html`。
> 原始全分辨率 PNG、命令输出、签名 HAP、缩略图脚本在同目录 `evidence/`、`material/`、`script/`。

| 环节 | 结果 | 证据 |
|---|---|---|
| DevEco JBR 21.0.8 + `hap-sign-tool.jar sign-app`（StarStack 缓存华为材料，口令脱敏） | ✅ `sign-app success` / `verify-app success` / `Digest verify result: true` | `evidence/sign-app-12.log`、`verify-app.log`、`cached-profile.json` |
| 缓存 profile 解码 | ✅ `verifiedPassed:true`，`type:debug`，`issuer:app_gallery`，绑定 `bundle-name: com.example.minimal`，UDID 命中，有效期 2026-11-04→2027-11-04 | `evidence/cached-profile.json` |
| `com.stargate.functionpanel` 安装 | ❌ `code:9568329 verify signature failed`（A）；`compatibleVersion 12/17` 都失败、证书链自洽 | `evidence/commands-and-results.txt` |
| 对照构建 `com.example.minimal` 安装 | ✅ `install bundle successfully`（B）；同材料、同命令、唯一变量 = 包名 → 根因钉死在 profile 包名绑定 | `evidence/commands-and-results.txt` |
| AGC 现场换发新 profile | ❌ 阻塞：`SIGN_FAILED {"code":-32001,"message":"登录已失效…"}` / `HTTP_STATUS=401`；凭据库无 refresh token，需交互重新登录 | `evidence/agc-ensure.log` |
| 4×4 卡片添加到桌面渲染 | ✅ FormMgr `FunctionPanelCard / FormId 637944382`；系统「服务卡片」搜索「功能面板」→ 添加至桌面 | 截图 06–10 |
| 卡片「更多 / 配置」跳转 | ✅ 修复后（修复前静默不跳转已复现） | 截图 11/12/15（修复前）→ 14/16/17/18（修复后） |

**真机暴露并 TDD 修复的两处生产缺陷**（均只在真机出现，本地单测无法发现）：
1. **Critical**：`postCardAction('router')` 缺顶层 `abilityName`（华为官方 router 事件要求），5 处点击全部静默不跳转。
   `PageRouter.routerAction<T>()` 把 `abilityName:'EntryAbility'` 固定在 action 顶层；WidgetCard 5 处调用改走它。
   测试 `router_action_carries_top_level_ability_name` RED→GREEN。
2. **Important**：Ability 已在前台时 `onNewWant` 只改 `page` 不重载 `loadContent`，切页显示上一页。
   `PageRouter.needsContentReload()` + 保存 `windowStage` + 条件重载；测试 `new_want_to_page_requires_content_reload` RED→GREEN。

**fresh 回归门**：`node test/run.mjs` → **39/39 PASS / 14 suites / exit 0**（`evidence/final-test-after-signing-fix.log`）；
`DEVECO_SDK_HOME=… hvigorw clean assembleHap` → **BUILD SUCCESSFUL / exit 0**（`evidence/final-build-after-signing-fix.log`）。

**安全边界**：AGC accessToken / keystore / key 口令仅在内存与工具 argv 中使用，日志、凭据读取脚本、证据、HTML 报告全部以 `***` 脱敏或只提字段名；
未复用外部工程 `/d/Code/CTFIfUCan/build-profile.json5` 密钥；未对第三方 App 实施注入/无障碍模拟点击；技术预研 Spec 未改动；无 git / commit / push / 发布动作。
`capabilities.json` 仍为空种子 `{items:[]}`，未回填任何未验证 URI（A3 诚实性保留）。
