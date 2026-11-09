# Task 5 Step 5 — `aa start` 落点实测（2026-11-07，真机 5KPBB25927200695）

## 结论（如实记录，A3 第二轮复核后晋升 4 条）

`aa start` 对候选 URI 返回 `start ability successfully` **只代表隐式 Want 已被派发/解析**，
**不等于**命中了 App 内部原子功能页。本机为无头 CLI 会话，无法可靠目视确认落点：

| 候选 | `aa start` 结果 | `aa dump -l` 前台 | 目视/布局证据 | 能否回填（A3） |
|---|---|---|---|---|
| `alipays://platformapi/startapp` | success | `com.alipay.mobile.client:EntryAbility` | 系统「暂无可用打开方式」弹窗 / 黑屏 | **否** |
| `weixin://` | success | `com.tencent.wechat:EntryAbility` | 未取到独立页面文字 | **否** |
| `amapuri://` | success | `com.amap.hmapp:EntryAbility` | 未取到独立页面文字 | **否** |
| `baidumap://` | **fail 10103101**（无匹配应用） | — | — | **否** |
| `stargate://nonexistent...`（负对照） | **fail 10103101** | — | 明确失败（符合预期） | 否 |
| `alipays://platformapi/startapp?saId=10000007` + 显式 ability | success | `EntryAbility` | 布局 dump（`-b com.alipay.mobile.client`）仅 420 字节、无文本节点 | **否** |

- `aa dump -l` 显示的前台始终是各 App 的 **`EntryAbility`（首页入口）**，而非可辨识的
  付款码/扫一扫/导航等原子页。
- 屏幕截图（evidence/`t5_*.png`）显示系统 USB 弹窗 / 黑屏 / 应用切换过渡，
  **没有出现可确认的原子功能页**。
- 第一轮候选均未能证明原子页落点，因此当时能力库保持空种子。第二轮人工读取截图后，4 条真实子页路由已晋升到正式能力库：高德路线规划、京东存储空间、微博存储空间、夸克千问助手。其余未验证 URI（包括 capability_scan.tsv 中的声明结果）仍不混入。

## 证据文件（本轮真实产物）
- `evidence/task5-aa-start.log`、`task5-aa-start2.log`：原始 `aa start` 输出
- `evidence/task5_screen.png`、`t5_alipay.png`、`t5_after_dismiss.png`、`t5_pay.png`：屏幕截图
- `evidence/task5-layout.json`、`t5_pay_layout.json`：`uitest dumpLayout` 输出

## 为何不强行验证
- 无头 CLI 无稳定 GUI 焦点；系统 USB 连接弹窗抢占窗口；商业 App 原子页常需登录/风控，
  用 `uitest` 自动点进真实第三方 App 的深层页面超出本任务边界（L5 注入/模拟点击攻击面，
  用户已明确只在工程层换方案、运行时不做降级，且不得针对真实第三方 App 实施模拟点击）。
- 按用户「失败不要回退，直接报告给我；不支持应该换方案」的产品立场：
  **这是工程/预研层的结论**——首版能力库宁可空、显示引导态，也不假装直达可用。
- 后续若需真机逐条验收，建议在 DevEco Studio 图形界面 + 人工目视下，
  对每个候选 URI 单独 force-stop → `aa start` → 目视落点 → 截图，再回填 `capabilities.json`。
