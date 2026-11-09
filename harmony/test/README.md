# 本地单测（Node 26 strip-types）

`hvigorw tasks` 在本机 SDK 下**不提供本地单测 task**（实测只有 assembleApp / PackageApp / SignApp 等）。
真正可跑的 RED/GREEN 入口是本目录的 Node 26 原生 TS strip-types 加载器：它直接 import 真实的 `.ets` 生产文件，
用 `@ohos/hypium` 的 shim 执行 hypium 风格断言；ArkUI/设备 API 以最小 shim 替代，只测纯逻辑。

## 运行（`harmony/` 工程根，单一命令）

在 `harmony/` 目录执行：

```
node test/run.mjs
```

- 退出码 0 = 全部通过；非 0 = 有失败或缺失套件（RED）。
- 单跑某个套件：`node test/run-one.mjs Smoke.test.ets`
- 该命令**不依赖** `hvigorw`，纯逻辑层可在任意 Node 26 环境复现；HAP 编译仍走 `hvigorw assembleHap`。
- `entry/src/test/List.test.ets` 是 DevEco Studio / hypium 侧的聚合入口（IDE 右键 `Run 'Tests in entry'` 用），
  与本 runner 的 `suites` 列表保持同步。

## 约束

- 生产 `.ets` 用 ArkTS 兼容写法：`interface` / 字符串字面量联合 / `const` 对象 / 泛型 / `as` 转换 / 可选链；
  **不用 TS `enum`、不用参数属性**（Node strip-only 模式不支持 `enum`，参数属性为保持可读性也不用）。
- 仅纯逻辑文件进 runner；`*.Ability.ets` / `*.Page.ets` / `WidgetCard.ets` 的 ArkUI `build()` 不在 Node 侧执行。
