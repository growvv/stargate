# 卡片平台前提探针结论（Task 0 · throwaway）

- 日期：2026-11-07
- 设备：`5KPBB25927200695`（UDID `2E8DDC0EA0…E731D4882118714C1B4452B19E5A1`），`const.ohos.apiversion=26`，HarmonyOS 7.0。
- 取证工具：`hvigorw`（`DEVECO_SDK_HOME=D:/Huawei/command-line-tools/sdk`）、`hdc` / `bm dump` / `uitest dumpLayout`、SDK `ets/build-tools/ets-loader/form_components/` 组件白名单、`ets/api/@ohos.app.form.*.d.ts` 声明、`hap-sign-tool.jar`。
- 证据目录：`.superpowers/sdd/2026-11-07-harmony-atomic-function-panel-product-plan/evidence/`（layout.json、sceneboard-dump.txt、wwdc18-211.html、app-library-2.html 等）。
- **一次性探针**：`probe/card_probe/` 源码不并入产品工程；本文件四个结论进入产品。

---

## ① `backdrop-filter` / 毛玻璃

**验证手段**：查 SDK 对 ArkTS 卡片（form）渲染进程的**组件/属性白名单**与 `@form` 注解；用 `hvigorw assembleHap` 编译含模糊属性的最小卡片 HAP，验证 ArkTS 编译链不拒绝。

| 检查项 | 命令/文件 | 实到结果 |
|---|---|---|
| 卡片属性白名单 | `form_components/common_attrs.json` → `attrs` | 含 `backgroundBlurStyle`、`blur`、`backdropBlur`（共 63 项） |
| `@form` 注解 | `declarations/common.d.ts:17544-17548` | `backdropBlur(value: number, options?: BlurOptions): T` 明确标 `@form` `@atomicservice` `@since 11` |
| 全量 App 白名单对比 | `components/common_attrs.json` | 额外还有 `foregroundBlurStyle`/`linearGradientBlur`/`motionBlur`/`windowBlur`——**卡片白名单是子集** |
| 卡片事件白名单 | `form_components/common_attrs.json` | 仅 `onClick` / `onAppear` / `onDisAppear`（无长按/拖拽/多指） |
| 参考工程真实编译 | `hvigorw assembleHap --mode module -p product=default` | 编译 ArkTS 成功（`CompileArkTS`/`PackageHap` 通过），**产出 unsigned HAP**；`SignHap` 因参考工程 2025-06-04 过期证书失败（不复用其密钥） |

**结论 `BLUR_SUPPORTED: true`**（静态取证级）。

> **Ruling（实现口径修正）**：计划/Spec 里写的 CSS 串 `backdrop-filter: blur(12–14px)` 是 HTML 线框稿的写法，**不是 ArkTS 卡片 API**。真实可用的是 ArkUI 属性 `backgroundBlurStyle(BlurStyle.*)` / `backdropBlur(13)` / `blur()`，它们带 `@form` 注解且在卡片白名单内。因此 `ThemeTokens.blur` 字段由 CSS 串改为 ArkUI 取值标记（`'blur(13)'` 语义值），`WidgetCard.ets` 用 `.backgroundBlurStyle(...)` 或 `.backdropBlur(13)` 落地；**不再依赖「CSS backdrop-filter 是否被卡片渲染支持」这个伪问题**。退化仍保留：若真机目视模糊不明显，用 `#ffffff4d` 半透纯色 + 渐变（不丢②基调）。
>
> 依据层级：静态 SDK 声明 + 编译链验证；**真机目视截图比对未做**（本 CLI 会话无法截取桌面渲染结果），故 `true` 指「API 层支持」，视觉表现以真机为准。

---

## ② 桌面长按菜单（`SYSTEM_EDIT_ENTRY`）

**验证手段**：`uitest dumpLayout` 拉当前桌面层级、`bm dump -n com.ohos.sceneboard -s` 查声明、查 Form Kit 是否有「卡片内编辑 Ability」契约。

| 检查项 | 实到结果 |
|---|---|
| 当前桌面层级 | `uitest dumpLayout` → `/data/local/tmp/layout_*.json`，139 节点，全部 `bundleName=com.ohos.sceneboard`（桌面 sceneboard 在前台）；未见自定义「编辑卡片」节点 |
| sceneboard `-s` 声明 | 719 字节，无 form/card/add/edit 相关 action/entity/uri 暴露给第三方 |
| Form Kit SDK | `@ohos.arkui.advanced.FormMenu.d.ets`（since 12）是「把卡片添加到桌面」的**添加表单菜单**，非卡片内编辑；`FormExtensionAbility` 回调只有 `onAddForm`/`onFormEvent`/`onUpdateForm`/`onRemoveForm`/`onCastToNormalForm`/`onConfigurationUpdate`/`onAcquireFormState`，**无「编辑配置页」回调** |
| 桌面长按菜单逐项文字 | **无法在本 headless CLI 会话获取**：需真机 GUI 长按 + 截图/目视；`dumpLayout` 只能拿静态层级，不能枚举长按弹出的菜单项 |

**结论 `SYSTEM_EDIT_ENTRY: false`**（产品保守取证结论；桌面长按由系统处理，系统菜单不保证提供拉起我们自定义配置 Ability 的入口）。

> 降级方案（Spec §3.2 / Task 6 `ConfigAccess`）：`isReachable(false)=false`、`firstAddGuideEnabled(false)=true` → **首次添加卡片时的引导配置**；产品里不存在「点了没反应」的死配置入口。`ConfigPage` 仍实现（由引导入口拉起），不依赖系统菜单。
>
> 依据层级：SDK 声明 + 布局 dump 静态取证；菜单项文字为本会话**未取到的真机交互项**，按「无证据即不假设有」取 false 并降级（**公开资料推断级**，非静态取证）。若真机后来证实存在该入口，只需把 `SYSTEM_EDIT_ENTRY` 改 true 并把配置入口挂到菜单，属配置层一行改动。

---

## ③ 事件链路（`EVENT_CHAIN`，A1 拍板）

**验证手段**：查 `postCardAction` 声明、`FormExtensionAbility` 回调、`FormExtensionContext` 是否具备 `startAbility`、卡片事件白名单。

| 检查项 | 实到结果 |
|---|---|
| `postCardAction` | `declarations/common.d.ts:1317` `declare function postCardAction(component: Object, action: Object): void;`（卡片专用全局函数） |
| `FormExtensionAbility.onFormEvent` | `ets/api/@ohos.app.form.FormExtensionAbility.d.ts:187` `onFormEvent(formId: string, message: string): void;`——文档明确「message 为 message 事件的 `params` 字段，用于标识触发的组件」，即 **`message` action 落到 `onFormEvent`** |
| `router` action | `router` 把 params 作为 Want 拉起 UIAbility（进 `EntryAbility.onCreate`/`onNewWant` 的 `want.parameters`）；适合「拉起分类/全量页」 |
| `call` action | `call` 拉起指定 UIAbility 到后台（无 UI），用于长时任务；**不适合点击直达** |
| `FormExtensionContext.startAbility` | `application/FormExtensionContext.d.ts:40` `class FormExtensionContext extends ExtensionContext {}`；`ExtensionContext` 继承链**无 `startAbility`**（`startAbility` 在 `UIAbilityContext`）。→ `FORM_CAN_START_ABILITY: false`（FormAbility 侧不能直接启第三方 Want） |
| 卡片事件白名单 | 仅 `onClick`（+`onAppear`/`onDisAppear`），`onClick` 内可调 `postCardAction` |

**结论 `EVENT_CHAIN: 'form-message'`（功能直达）+ 辅 `router`（拉起页面）**；`FORM_CAN_START_ABILITY: false`。

> **建议的卡片点击实现方式（供 Task 3/5）**：
> - 卡片上「建议图标 / 功能项」点击 → `postCardAction(this, { action: 'message', params: { functionId } })` → `FormAbility.onFormEvent(formId, message)` 解析 `functionId` → **由 `FormAbility` 侧通过 `formProvider` 无法直接启第三方**（无 `startAbility`）；改为 `onFormEvent` 里用 `postCardAction` 的 **`router`** 把带 `functionId` 的 Want 转给 `EntryAbility`（或 `call` 到后台 UIAbility），在 **`EntryAbility`/UIAbility 侧**执行 `startAbility(第三方 Want)`。
> - 卡片上「分类 chip / ⋯ 更多」点击 → `postCardAction(this, { action: 'router', params: { page:'category'|'all', category? } })` → `EntryAbility` 读 `want.parameters.page` 路由到 `CategoryPage` / `AllFunctionsPage`。
> - **直达逻辑落点**：`LaunchDispatcher` 运行在 **UIAbility 侧**（有 `startAbility`），不是 FormAbility 侧。这与计划 Task 5「`LaunchDispatcher` 在 FormAbility/UIAbility 侧」的较宽表述一致，本结论把它**收窄到 UIAbility 侧**。
> - 依据层级：SDK 声明静态取证；三 action 的**运行时回调落点**未做真机三按钮打印（headless 限制），按 SDK 文档语义定，Task 5 真机 `aa start` 落点实测再复核。

---

## ④ 卡片添加路径（`CARD_ADD_PATH`，§0.9 B1′）

**验证手段**：查 `hdc install` 是否可用、`bm install` 是否要求签名、Form Kit 添加表单契约、无 Launcher 入口 HAP 是否仍可出现在卡片管理列表。

| 检查项 | 实到结果 |
|---|---|
| `hdc install` / `bm install -p <hap>` | 设备在线，`bm install` 支持 `-p` 装 HAP；**HarmonyOS NEXT 要求 HAP 签名**（参考工程 unsigned HAP 不能直装，签名过期证书亦失败） |
| 本机签名材料 | `~/.ohos/config/` 有 DevEco 自动签名 `.cer/.p12/.p7b`（2025 年生成）；SDK 自带 `OpenHarmony.p12` 与 `hap-sign-tool.jar`（可本地自签）；无需复用参考工程密钥 |
| 无 Launcher 入口 HAP | `module.json5` 不配 `ohos.want.action.home` / `entity.system.home` 的 Launcher skill 时，App **不出现在桌面应用列表**，但 `FormExtensionAbility` + `FormMenu`(since 12) 仍可被**卡片管理/服务卡片列表**枚举并添加（Form Kit 契约） |
| 真实用户路径「桌面长按→服务卡片→找我们的 HAP→添加」 | **需真机 GUI 交互，本 headless CLI 无法完成**；`uitest uiInput click/longClick` 可注入坐标，但「服务卡片列表里是否出现无 Launcher 入口 HAP」需目视截图确认，本会话不伪造截图 |

**结论 `CARD_ADD_PATH: 'dev-install-only'`**（本期内部自用/真机演示，D1；以 `hdc install` 开发期安装 + 卡片管理添加为准）。

> 说明：三选一里 `no-launcher-ok`（完全无 Launcher 且用户可自助添加）与 `needs-launcher-guide`（需最小 Launcher 引导页）都**需要真机 GUI 验证用户自助路径**，本会话无法给出静态取证；按「无证据不假设用户能自助找到」的保守口径选 `dev-install-only`（**公开资料推断级**）。
> **Task 1 `module.json5` 处置**：仍**不暴露产品主 UI 入口**（符合「不需要 App」）；仅保留 `FormExtensionAbility` 声明与一个**非 Launcher 的 `EntryAbility`**（用于 router 拉起的分类/全量/配置页，`exported` 按需），不配 `entity.system.home`。签名用本地生成材料，不复制参考工程 `build-profile.json5` 密钥。若明早真机证实卡片列表可直接添加，可把该值改 `no-launcher-ok`，工程无需改动。

---

## 汇总（四个结论）

| 结论 | 值 | 依据层级 | 真机 GUI 未取项 |
|---|---|---|---|
| `BLUR_SUPPORTED` | `true` | 静态 SDK 声明 + 编译链 | 目视模糊效果截图 |
| `SYSTEM_EDIT_ENTRY` | `false` | SDK 声明 + 布局 dump（保守推断） | 长按菜单项文字 |
| `EVENT_CHAIN` | `'form-message'`（+ `router` 拉页）；`FORM_CAN_START_ABILITY=false` | 静态 SDK 声明 | 三按钮回调打印 |
| `CARD_ADD_PATH` | `'dev-install-only'` | 静态契约 + 保守推断 | 卡片管理列表可见性/添加截图 |

**未做 / 如实标注**：真机 GUI 长按菜单枚举、桌面添加卡片截图、毛玻璃目视对比、三 action 运行时回调打印、`aa start` 落点实测（属 Task 5）。本任务为 throwaway 地基探针，四个结论供 Task 1 / Task 3 / Task 5 / Task 6 读取；**源码不并入产品工程**。

**编译实证（Step 2）**：`probe/card_probe/` 一次性最小工程（Form Kit 4×4 卡片 + `backdropBlur(13)` + `linearGradient`），`hvigorw assembleHap --mode module -p product=default` → **BUILD SUCCESSFUL**（`CompileArkTS` / `PackageHap` 通过，产出 `entry-default-unsigned.hap`）。HAP 清单含 `module.json`（`extensionAbilities` 有 `type:"form"` 的 `ProbeFormAbility`）、`resources/base/profile/form_config.json`（`defaultDimension:"4*4"`）、`ets/widgets.abc`、`ets/widget/component_collection.json`。**`widgets.abc` 内字面量含 `backdropBlur` / `linearGradient` / `borderRadius`**，证明卡片编译链接受模糊属性（非 CSS 伪问题）。签名未配 → `SignHap` 跳过（WARN：「No signingConfigs profile」），产物 unsigned，符合 throwaway 定位；**未复用参考工程过期密钥**。

**产物**：`probe/card_feasibility.md`（本文件）、`probe/card_probe/`（一次性最小工程 + unsigned HAP）、evidence 目录日志（`layout.json` / `sceneboard-dump.txt` / `wwdc18-211.html` / `app-library-2.html` / `aa-cert.cer` 等）。
