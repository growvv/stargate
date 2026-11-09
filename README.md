# 鸿蒙功能聚合面板（卡片优先）

> 当前扩展验收：`node test/run.mjs` 为 127 tests / 31 suites / 0 failed。2026-11-08 的命令行 HAP 重建被本机 SDK 缺少 `hmscore` 组件阻塞；详见 [`docs/research/capability-panel-expansion-acceptance.md`](docs/research/capability-panel-expansion-acceptance.md)。

HarmonyOS NEXT / ArkTS / Stage / API 26。产品形态：**桌面 4×4 服务卡片**，无独立 App 主界面；
卡片一点即走直达目标 App 原子功能，分类 / 全量 / 搜索页由点击拉起。

## 工程说明

- 单 HAP：`FormAbility`（FormExtensionAbility）+ `EntryAbility`（拉起页面）+ ArkTS 卡片 `WidgetCard`。
- 卡片与提供方独立进程，数据经 `formBindingData` / `@LocalStorageProp` 传递。
- 第一期内部自用 / 真机演示（D1），不上架；图标引用第三方 App 图标（D2）。
- 能力库为本地可替换配置文件（D5）：`entry/src/main/resources/rawfile/capabilities.json`；运行时经 `CapabilityRepository.fromContextSync(context)` 读取（外部 `/data/storage/el2/base/haps/entry/files/capabilities.json` 优先，rawfile 种子兜底，UTF-8 正确解码），卡片/直达/分类/全量四个消费者均已接入，非死代码。
- 无收藏 / 手动添加 / 推荐开关 / 用量查看与清空（B1 / B2 / D4）；建议区完全自动、最多 8 格、不足按实际（B2′）。
- 直达失败**不回退 App 首页、不做多路由降级**，明确报告「暂无可用直达入口」。

## 平台前提（Task 0 实测结论，详见 `probe/card_feasibility.md`）

| 结论 | 值 | 含义 |
|---|---|---|
| `BLUR_SUPPORTED` | `true` | ArkTS 卡片白名单含 `backdropBlur` / `backgroundBlurStyle`（`@form` 注解）；编译进 `widgets.abc` 实证。用 ArkUI 属性而非 CSS `backdrop-filter` |
| `SYSTEM_EDIT_ENTRY` | `false` | 桌面长按菜单不保证提供自定义配置入口；配置改走卡片空态「配置」按钮 / `formConfigAbility`，`ConfigAccess.firstAddGuideEnabled(false) === true` |
| `EVENT_CHAIN` | `form-message`（诊断）+ `router`（拉页/直达） | 页面分类/更多/功能点击均用 `postCardAction('router')` → `EntryAbility`（`want.parameters.page`）；`FORM_CAN_START_ABILITY=false`，故 `LaunchDispatcher` 落 **UIAbility 侧**（唯一有 `startAbility` 的进程）。`FormAbility.onFormEvent` 的 `message` 链仅作诊断/遥测 + A2 重排，见 Task 5 Ruling |
| `CARD_ADD_PATH` | `dev-install-only` | 本期开发期 `hdc install` + 卡片管理添加；**不暴露 Launcher 主 UI 入口** |

依据层级与「真机 GUI 未取项」见 `probe/card_feasibility.md`（长按菜单文字 / 桌面添加截图 / 目视模糊 / 三 action 回调打印均未伪造）。
`IOS_*_SPEC` 四组定稿见 `docs/superpowers/specs/2026-11-07-harmony-atomic-function-panel-ios-aligned-design.md`。

## 本地单测

**本地单测：`node test/run.mjs`**（工程根）。
`hvigorw tasks` 实测无本地单测 task，故用 Node 26 原生 TS strip-types 加载器直接跑真实 `.ets` 生产文件；
详见 `test/README.md`。IDE 侧也可用 DevEco Studio → 右键 `entry/src/test` → Run 'Tests in entry'。

## 构建

```
DEVECO_SDK_HOME=D:/Huawei/command-line-tools/sdk \
  /d/Huawei/command-line-tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default
```
产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。
签名需本机 DevEco 自动签名材料；**不复制 `/d/Code/CTFIfUCan/build-profile.json5` 的密钥**。

> **真机签名 / 安装现状（2026-11-07 更新，如实记录）**：见下方「真机签名与截图验证」新节与自包含 HTML 报告
> `.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/verify-signing/screenshot-validation-report.html`。
> 要点：① `hvigorw` 固定用系统 OpenJDK 21，`SignHap` 会触发 `Invalid CEN header (zip64)`；但换成 DevEco Studio 自带 JBR 21.0.8 跑独立
> `hap-sign-tool.jar sign-app`，用 StarStack 缓存的华为调试材料（p12 / cer / p7b）**可成功签名并 `verify-app` 通过**。
> ② 缓存 profile 由华为 `app_gallery` 签发、绑定 `bundle-name: com.example.minimal`，与产品真实包名
> `com.stargate.functionpanel` 不一致；设备以 `code:9568329 verify signature failed` 拒绝真实包名 HAP（A/B 对照实验钉死此根因）。
> ③ 为 `com.stargate.functionpanel` 现场申请新 profile 需交互重新登录华为账号；缓存 AGC accessToken 已过期（HTTP 401，凭据库无 refresh token），
> 无头会话无法续期，**本次未创建任何 AGC 资源、未做任何交互式登录**。
> ④ 因此真机安装/截图用的是**对照构建**（仅 `AppScope/app.json5` 包名改为 `com.example.minimal`，产品源码一致），
> 已成功 `hdc install`、经系统「服务卡片」搜索「功能面板」添加到桌面、目视 4×4 渲染并取 19 张真机截图。
> ⑤ 真机交互还发现并 TDD 修复了两处生产缺陷（卡片 router 缺顶层 `abilityName` 导致点击不跳转；`onNewWant` 切页不重载）。
> 未复用任何参考工程密钥、未解密/再分发 DevEco 管理的签名口令；AGC token / keystore 口令仅在内存与工具 argv 中使用，日志与报告全部脱敏。
> 明早验收若需安装**产品真实包名**，先在 StarStack / DevEco 里重新登录华为账号，让自动签名为 `com.stargate.functionpanel` 申请绑定该包名的新调试 profile。

## 设备侧测试

`entry/src/ohosTest/` 依赖 uitest 扩展（StarStack 逆向笔记），仅测试态、仅验证我们自己的 HAP/卡片，
不进运行时、不针对真实第三方 App 模拟点击。扩展 API 名现场核对后接入（见该目录 README）。

## 交付校验

见 `docs/superpowers/plans/2026-11-07-harmony-atomic-function-panel-checklist.md`（Task 6 产出）。

**第一期实现状态（2026-11-07 / `/goal` 自主执行完毕 + fresh reviewer 单趟修复）**：
- ✅ **37/37 本地单测 PASS**（`node test/run.mjs`，含评审后新增 11 项）；✅ `hvigorw clean assembleHap` 从零 BUILD SUCCESSFUL（真实 ArkTS，编译错误经 systematic-debugging 定位为 `arkts-no-structural-typing` 后改用 SDK 真实类型修复）。
- ✅ 数据层、4×4 卡片 UI、分类/全量/配置页、直达链路（单次 Want / 无 home 回退 / 无多路由降级）、
  `IOS_VISUAL_SPEC`/`IOS_RANKING_SPEC`/`IOS_CATEGORY_SPEC`/`IOS_PINYIN_SPEC` 四组定稿全部落地并编译进 HAP。
- ✅ **评审后单趟修复**（fresh reviewer 全量终审）：C1（四个运行时消费者接入真实 D5 能力库）、
  I1（Want 显式带 bundleName）、I2（卡片直达失败显示「暂无可用直达入口」）、I3（用量经 Preferences 持久化 + 成功后重排）、
  I4（冷启动时段先验）、I5（配置页经卡片「配置」按钮 / formConfigAbility 可达，非死入口）、
  I6（A–Z 索引点击跳组）、I7（卡片消费暗色/无模糊退化主题），外加自发现的 UTF-8 中文种子乱码缺陷。
  全部 RED→GREEN，符号实测编译进 `modules.abc` / `widgets.abc`。
- ✅ **真机签名 / 桌面 4×4 卡片渲染已打通（2026-11-07 追加）**：用 JBR 21 + StarStack 缓存的华为调试材料
  离线 `sign-app` / `verify-app` 成功；对照构建（仅包名对齐缓存 profile）`hdc install` 成功、经系统「服务卡片」
  搜索「功能面板」添加到桌面并目视 4×4 渲染，19 张真机截图见下方「真机签名与截图验证」。
  真机交互额外暴露并 TDD 修复两处生产缺陷 → 本地单测 **39/39 PASS**、`hvigorw clean assembleHap` BUILD SUCCESSFUL。
- ⚠️ **仍被阻塞 / 未验证（如实保留）**：① 产品真实包名 `com.stargate.functionpanel` 的现场安装被
  `code:9568329`（缓存 profile 绑定 `com.example.minimal`）阻塞，需交互重新登录华为账号申请新 profile（本次 AGC 401，未登录、未建资源）；
  ② 真机 `aa start` 落点仍未证实命中第三方 App 原子功能页（见 `probe/aa_start_landing_probe.md`）。
  按 A3 与「失败不回退、如实报告」立场，`capabilities.json` 只回填 4 条经过真机截图确认的原子页路由（高德路线规划、京东存储空间、微博存储空间、夸克千问助手）；支付宝付款码、微信扫一扫、高德打车等未确认 URI 仍未回填。

- ✅ **能力探索面已扩充**：`discovery-candidates.json` 将声明账本中的 48 个 App、325 条 Scheme/Link/Shortcut/路径线索接入“能力探索”页，可按 App、包名和入口线索搜索；候选显示证据层级与验证边界，不会直接混入生产能力库。详细验收记录见 [`docs/research/capability-panel-expansion-acceptance.md`](docs/research/capability-panel-expansion-acceptance.md)。
- 三条产品硬约束（建议区全自动、失败不回退首页/不多路由降级、换方案只在工程层）在代码与测试中均已守住。
- 评审的 Minor（M2 typed Want、M3 第三方图标、M4 上滑关闭、M7 seqBoost 全量序列）按 executing-plans 门控延后，见交接说明「Deferred minors」。

## 真机签名与截图验证（2026-11-07 追加）

> 用户要求「用已登录的 StarStack 签名机制签名 → 真机截图验证 → 出 HTML 截图验证报告」。
> **交付物：自包含 HTML 报告（19 张截图 base64 内嵌，无外链、无密钥明文）**
> `.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/verify-signing/screenshot-validation-report.html`
> （双击即可在浏览器打开）。原始全分辨率 PNG / 命令输出 / 签名的 HAP / 缩略图生成脚本均在同目录 `evidence/`、`material/`、`script/` 下。

| 环节 | 结果 | 关键证据 |
|---|---|---|
| 华为调试材料离线签名 | ✅ | JBR 21.0.8 + `hap-sign-tool.jar sign-app -compatibleVersion 12` → `sign-app success`；`verify-app` → `Digest verify result: true`（口令全程脱敏） |
| `com.stargate.functionpanel` 安装 | ❌ 阻塞 | `code:9568329 verify signature failed`；A/B 对照证明根因是缓存 profile 绑定 `com.example.minimal`；AGC token 401，无法现场申请新 profile |
| 对照构建 `com.example.minimal` 安装 | ✅ | `install bundle successfully`（仅 `AppScope/app.json5` 包名不同，产品源码一致） |
| 4×4 卡片添加到桌面并渲染 | ✅ | FormMgr `FunctionPanelCard / FormId 637944382`；系统「服务卡片」搜索「功能面板」→ 添加到桌面 → 真机截图 |
| 卡片「更多」「配置」点击 | ✅ 修复后 | 修复前静默不跳转（已复现）→ 修复后打开全量页 / 配置页（冷+热态） |

**真机发现并修复的两处生产缺陷（TDD RED→GREEN，均只在真机暴露）**：
1. **Critical**：`postCardAction('router')` 缺顶层 `abilityName`（华为官方要求），5 处点击全部静默不跳转。
   新增 `PageRouter.routerAction<T>()` 把 `abilityName: 'EntryAbility'` 固定在 action 顶层；WidgetCard 5 处调用改走它。
   测试 `router_action_carries_top_level_ability_name` RED→GREEN；真机截图 11/12（修复前）→ 14（修复后）。
2. **Important**：Ability 已在前台时 `onNewWant` 只更新 `page` 不重新 `loadContent`，切页显示上一页。
   新增 `PageRouter.needsContentReload()` + 保存 `windowStage` + 条件重载；测试 `new_want_to_page_requires_content_reload` RED→GREEN；
   真机截图 15（修复前热态残留）→ 17/18（修复后热态重载）。

**回归门**：`node test/run.mjs` → 39/39 PASS / 14 suites / exit 0；`DEVECO_SDK_HOME=… hvigorw clean assembleHap` → BUILD SUCCESSFUL / exit 0。

**安全边界**：AGC accessToken / keystore / key 口令仅在内存与工具 argv 中使用，日志、凭据读取脚本、证据文件、HTML 报告一律以 `***` 脱敏或只提字段名；
未复用外部工程 `/d/Code/CTFIfUCan/build-profile.json5` 的密钥；未对第三方 App 实施注入/无障碍模拟点击；技术预研 Spec 未改动；无 git / commit / push / 发布动作。
