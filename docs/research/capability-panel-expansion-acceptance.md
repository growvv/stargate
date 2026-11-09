# Stargate 能力面板扩展验收报告

- 日期：2026-11-08
- 真机：5KPBB25927200695（HUAWEI MatePad Mini，HarmonyOS 7.0.0.111 SP16）
- 目标：扩充能力发现面，同时保证卡片只暴露经过页面证据确认的直达入口。

## 交付结果

### 生产可直接使用

`capabilities.json` 保持 4 条 L0/L5 证据入口：高德路线规划、京东存储空间、微博存储空间、夸克千问助手。四条均从面板点击并在第三方 App 页面截图确认；证据索引见 `verified-routes.json` 和 `e2e-round2-results.json`。

### 能力探索候选面

新增 `discovery-candidates.json` 与 `DiscoveryCandidateCatalog`。它把声明账本投影到面板，当前包含：

- 48 个 App；
- 37 个有公开声明的 App；
- 11 个没有公开 scheme/link/shortcut/path 提示的 App；
- 325 条入口线索；
- 37 个 App 有 Scheme、22 个有 Link 特性、17 个有 Shortcut；
- 生产可用晋级数：0（候选不会伪装成可用入口）。

探索页现在可以按 App 名、包名、Scheme、Link 特性、Shortcut 和路径提示搜索；每个候选显示来源层级、状态、线索摘要和“点击前需验证”边界。

## REA 取证

REA CLI `inspect-artifact` 已对工作区中现有的 unsigned HAP 快照执行静态清单分析（该 HAP 早于本次候选面改动；新 HAP 因 SDK 完整性问题尚未生成）：

- Evidence ID：`ev_6d12a9766471abcdc3bfb650fc308ca0e21a67a450108d935d2d6c6a45efa698`；
- HAP SHA-256：`1b53d046195fc0f3851f115c8a4424e863f160f9ad5fbe3d6ec7a4c7478afdbb`；
- 14 个节点 / 14 个文件 occurrence / 13 条包含边；
- 证据文件：`evidence/rea-entry-hap-evidence.json`。

REA 证明的是这个已生成 HAP 快照的包清单和文件身份，不证明第三方 App 的运行时行为，也不代表新候选文件已经进入 HAP。工作区没有 48 个第三方 App 的原始 HAP，因此不能把 REA 字符串线索凭空扩展成生产路由；下一轮只需把设备导出的目标 HAP 逐个送入同一流程，并保留 Evidence ID 与 SHA-256。

## 测试记录

| 步骤 | 目标 | 实际结果 | 状态 | 证据 |
|---|---|---|---|---|
| 1 | 纯逻辑回归 | 127 tests / 31 suites，0 failed | PASS | `node test/run.mjs` 输出 |
| 2 | 候选解析与搜索 | 48 条候选可解析；按“京东”与“RoutePlan”过滤命中 | PASS | `DiscoveryCandidateCatalog.test.ets` |
| 3 | 全部功能搜索 | 5 项入口；“京东”命中 1 项；不存在命中 0 项 | PASS | `acceptance-results.json`、`01-all.png`、`02-search-jd.png`、`04-search-nomatch.png` |
| 4 | 分类搜索 | 购物分类命中京东；分类内搜索仍命中 | PASS | `05-category-shopping.png`、`06-category-search-jd.png` |
| 5 | 能力库配置与探索入口 | 设置页可打开能力探索，显示外部能力库路径 | PASS | `07-config.png` |
| 6 | 真实直达入口 | 高德、京东、微博、夸克均落到目标子页 | PASS | `a3-probe/evidence/verified-routes.json`、`amap-2-landed.png`、`jd-2-landed.png`、`weibo-2-landed.png`、`quark-2-landed.png` |
| 7 | 无效路由边界 | 对照路由保留在面板并显示“暂无可用直达入口” | PASS | `invalid-2-landed.png` |
| 8 | 推荐链路 | 点击京东后第三方页面可见，返回卡片重新绑定 | PASS | `recommendation-result.json`、`recommend_before.png`、`recommend_after-launch.png`、`recommend_after-return.png` |
| 9 | HAP 静态取证 | REA 清单成功，未把声明提升为运行时路由 | PASS | `rea-entry-hap-evidence.json` |
| 10 | ArkTS/HAP 构建 | 当前命令行 SDK 完整性检查失败（SDK component missing）；不是代码测试失败 | BLOCKED | `evidence/final-build-discovery.log` |

推荐测试 JSON 中的截图文件名已修正为实际生成的下划线文件名；卡片无障碍树不暴露品牌图标对应文字，因此推荐顺序由真实第三方落地、UsageStore 持久化和 RankingEngine 单测共同验证。

## 后续探测顺序

1. 对设备导出的第三方 HAP 运行 REA 包清单、路由字符串和资源分析，记录 Evidence ID / SHA-256。
2. 对声明候选逐条执行单 URI `aa start`，只接受截图或布局树确认的原子页。
3. 对登录页、首页、chooser、H5 中转页和隐私首屏标记 rejected/unavailable，不写入 `capabilities.json`。
4. 对无声明的 11 个 App 优先走 REA，再走受控 UI Test；UI Test 只用于测试态验证，不对第三方 App 做模拟点击。
