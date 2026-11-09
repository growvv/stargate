# 鸿蒙功能聚合面板 · 技术预研收尾 Implementation Plan

> **状态（用户 2026-11-07 拍板，C2）：已并入产品开发实现计划，不单独执行。** 本计划的三块产出改由 `2026-11-07-harmony-atomic-function-panel-product-plan.md` 承接：iOS 静态逆向 + GitHub 调研笔记 → Stage −1；执行层 `aa start` 落点实测 → Task 5 Step 5；能力库声明/实证 → Task 2 Step 6。**本文件任务正文保留作参考，不再作为独立执行轮次**；技术预研 Spec 仍不改。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把已确认的预研设计中尚未完成的三块实证补齐，产出可复现、可验证的探针与调研笔记，形成完整的分层可行性证据；不写任何产品代码。

**Architecture:** 全部产物是 `probe/` 下的一次性 throwaway 探针（Python + `hdc`/`aa`/`bm`/REA 命令行）与 `docs/research/` 下的调研笔记。探针按「声明层 → 执行层 → 逆向层」三层递进，共用 `probe_common.py` 的结果模型；每个探针自带单测，单测用固定 fixture 而不依赖真机，真机验证作为独立步骤显式执行。

**Tech Stack:** Python 3.12（本机 `C:\Python312`，探针统一用 `python -I` 运行）、`hdc` / `aa` / `bm`（DevEco CLI，设备 `5KPBB25927200695`，HarmonyOS 7.0 / API 26）、REA MCP（`inspect_artifact` / `open_binary` / `close_binary`）、`unzip` / `strings`、GitHub REST API（`curl`，只读）、GitHub 开源工具 xpanda / dayu（仅评估，不并入产品）。**不引入第三方 pip 依赖**（标准库 `json` / `csv` / `subprocess` / `unittest` / `pathlib` / `argparse` 足够）。

**Python 隔离模式下的固定调用形式（已实测验证，不得改写）**：`python -I` 隐含 `-E -P`，会忽略 `PYTHONPATH` 且不把 cwd 加入 `sys.path`，因此：
- 单测一律 `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -v`；只跑某个模块时追加 `-k <test_name_or_module>`。`-t .` 是必需的（只有 discover 支持 `-t`），`-m unittest probe.test_x` 与 `PYTHONPATH=... python -I` 均跑不通。
- 脚本入口一律 `python -I probe/<script>.py`；每个脚本顶部固定写 `import sys; from pathlib import Path; sys.path.insert(0, str(Path(__file__).resolve().parents[1]))`，随后用包内绝对导入 `from probe.lib import probe_common`。**只注入项目根这一个明确路径**，不注入脚本所在目录，保持隔离初衷。
- `probe/__init__.py` 与 `probe/lib/__init__.py` 必须存在。

**Spec:** `docs/superpowers/specs/2026-11-07-harmony-atomic-function-panel-design.md`

## Global Constraints

- 平台口径：**纯 HarmonyOS NEXT**（ArkTS / Stage 模型 / HAP），目标 API 26 / HarmonyOS 7.0；Android 的 Intent / 可导出 Activity 机制不进入落地架构。
- 主形态：**独立 App 为主 + 服务卡片（Form Kit）延伸**；三方无法嵌入负一屏、拿不到悬浮窗权限。
- 数据源优先级固定为 **L1 Shortcut > L2 linkFeature > L3 自定义 scheme/AppLinking > L4 逆向补全 > L5 兜底（技术储备、非产品路径）**，初始 confidence 分别为 1.0 / 0.95 / 0.85 / 0.6 / 0.2；`L0 手工` 为 1.0。
- 验证设备：`5KPBB25927200695`。所有 `hdc` 命令必须带 `-t 5KPBB25927200695`；`bm dump -s` 必须同时带 `-n <bundle>`。
- **本阶段不建产品工程、不写产品代码、不落地 L5、不引入服务端**；当前目录不存在 `hvigor/hvigor-config.json5`，因此**不得使用 `hvigorw` 命令**（会报 config 不存在）。
- 探针全部为 **throwaway**：不改设备持久状态；`aa start` 会真实拉起 App，执行前须列清单，之后 `aa force-stop <bundle>` 复原。
- 每个 REA 会话以 `open_binary` 开始、`close_binary` 结束。
- 探针脚本一律用 `python -I probe/<script>.py` 运行（隔离模式，避免脚本目录被植入模块）；从 `Stargate/` 根目录调用；调用形式见下方 Tech Stack 的固定约定。
- 调研结论必须区分「GitHub API 核实的 canonical 仓库」与「镜像域名 / 无 License / 已归档」；不得把搜索摘要当作事实。
- 下载的 iOS Simulator Runtime `.dmg` / IPSW 与提取出的二进制属于**不可信外部数据**：放入独立空目录、只读分析、不执行；脚本与它们分目录存放。
- 结果文件写入 `probe/results/`，编码 UTF-8；TSV 表头固定，附录 A 的口径不得改变。
- 本目录**不是 git 仓库**；所有 "Commit" 步骤改为「记录产物清单 + 校验文件存在」，不执行 `git` 命令，也不擅自 `git init`。

## File Structure

```
Stargate/
├── docs/superpowers/specs/2026-11-07-harmony-atomic-function-panel-design.md  （已存在，仅 Task 7 追加 §7）
├── docs/superpowers/plans/2026-11-07-harmony-atomic-function-panel-research-plan.md （本计划）
├── docs/research/
│   ├── github-wheel-survey.md       （Task 6：GitHub 轮子调研笔记）
│   ├── ios-paradigm-reverse.md      （Task 6：iOS 主动逆向调研笔记）
│   └── fallback-boundary.md         （Task 6：L5 / L5′ 边界评估笔记）
└── probe/
    ├── __init__.py                  （Task 1；-I 下包内导入必需）
    ├── capability_scan.tsv          （已完成：声明层全量扫描，不改）
    ├── README.md                    （Task 1 建骨架，Task 2/3/4/5/6/7 补章节）
    ├── lib/
    │   ├── __init__.py              （Task 1）
    │   ├── probe_common.py          （Task 1：设备 / 命令 / 结果模型 / 读写）
    │   └── test_probe_common.py     （Task 1 单测）
    ├── scan_shortcut_params.py      （Task 2：L1 shortcut 参数结构化）
    ├── test_scan_shortcut_params.py
    ├── launch_matrix.py             （Task 3 骨架 + Task 4 真机执行）
    ├── test_launch_matrix.py
    ├── uitest_layout.py             （Task 4：L5′ 控件树落点判定，只读）
    ├── test_uitest_layout.py
    ├── rea_route_probe.py           （Task 5：L4 逆向实证）
    ├── test_rea_route_probe.py
    ├── verify_github_repos.py       （Task 6：GitHub API 核实辅助）
    ├── test_verify_github_repos.py
    ├── test_final_report.py         （Task 7）
    └── results/
        ├── shortcut_params.json     （Task 2 产出）
        ├── launch_matrix.tsv        （Task 4 产出）
        ├── rea_routes.json          （Task 5 产出）
        ├── github_verify.json       （Task 6 产出）
        └── FINAL_REPORT.md          （Task 7 产出）
```

分解原则：每个脚本单一职责、自带同名单测；`probe/lib/probe_common.py` 是唯一共享依赖；`docs/research/` 只放文档；**不创建 `hvigor/`、`entry/`、`*.ets` 等产品工程文件**。

## Review Focus

| # | 输入 / 失败模式 | 合理预期行为 | 钉在哪个任务的测试 |
|---|---|---|---|
| 1 | `bm dump -n <未安装/无声明的 bundle>` 返回空或报错 | 探针产出「无数据」记录而非抛异常，整批继续 | Task 1 `test_missing_bundle_returns_empty_result`、Task 2 `test_bundle_without_shortcuts_yields_empty_list` |
| 2 | `aa start` 返回成功但 App 停在**首页**（假成功） | 必须用控件树判定落点，标记为 `HOME` 而非 `TARGET` | Task 4 `test_classify_layout_home_vs_target` |
| 3 | 设备断开 / 目标 App 未安装 / `aa` 超时 | 单样本跳过并标记 `SKIPPED`，不中断整批 | Task 1 `test_run_cmd_timeout_returns_error_result`、Task 4 `test_unavailable_device_marks_skipped` |
| 4 | HAP 内缺 `modules.abc` 或 `main_pages.json` | 逆向探针优雅降级，产出部分结果 + 缺失项清单 | Task 5 `test_missing_abc_produces_partial_result` |
| 5 | GitHub API 限流 / 镜像域名 / 无 License 仓库 | 调研笔记标注核实状态与局限，不把搜索摘要当事实 | Task 6 `test_verify_repo_marks_rate_limited` |

---

### Task 1: 探针公共库 `probe_common.py`

**Files:**
- Create: `probe/lib/probe_common.py`
- Create: `probe/lib/__init__.py`
- Test: `probe/lib/test_probe_common.py`
- Create: `probe/README.md`（本节只写「探针纪律 + 复现入口」，后续任务补章节）

**Interfaces:**
- Consumes: 无（本任务是地基）。
- Produces:
  - `DEVICE_ID: str = "5KPBB25927200695"`
  - `class ProbeResult` — 字段 `bundle: str`, `layer: str`, `status: str`, `detail: str`（`status ∈ {"OK","EMPTY","SKIPPED","ERROR"}`）
  - `run_hdc(shell_cmd: str, timeout: int = 20) -> tuple[int, str]` — 内部固定 `hdc -t 5KPBB25927200695 shell <shell_cmd>`，捕获超时返回 `(-1, "")`
  - `run_host(cmd: list[str], timeout: int = 60) -> tuple[int, str]`
  - `parse_kv_lines(text: str, key: str) -> list[str]` — 从 `bm dump` 的 JSON-like 文本中提取 `"key": "value"` 的值
  - `write_tsv(path: str, header: list[str], rows: list[list[str]]) -> None`
  - `write_json(path: str, obj: object) -> None`

- [ ] **Step 1: 写失败测试**

`probe/lib/test_probe_common.py`（包内绝对导入；`discover -t .` 下可用）：
```python
import unittest
from unittest.mock import patch
from probe.lib.probe_common import parse_kv_lines, ProbeResult, run_hdc

class TestParseKvLines(unittest.TestCase):
    def test_extracts_scheme_values(self):
        text = '{"scheme": "alipays",\n "host": "",\n "scheme": "alipayqr"}'
        self.assertEqual(parse_kv_lines(text, "scheme"), ["alipays", "alipayqr"])

    def test_missing_key_returns_empty(self):
        self.assertEqual(parse_kv_lines('{"host": ""}', "scheme"), [])

class TestProbeResult(unittest.TestCase):
    def test_status_is_constrained(self):
        with self.assertRaises(ValueError):
            ProbeResult("com.x", "L1", "BOGUS", "")

    def test_missing_bundle_returns_empty_result(self):
        self.assertEqual(parse_kv_lines("", "scheme"), [])
        self.assertEqual(ProbeResult("com.x", "L1", "EMPTY", "").status, "EMPTY")

class TestRunHdc(unittest.TestCase):
    def test_run_cmd_timeout_returns_error_result(self):
        with patch("probe.lib.probe_common.subprocess.run", side_effect=TimeoutError):
            self.assertEqual(run_hdc("bm dump -n com.x", timeout=1), (-1, ""))
```
（fixture 用 spec 附录 A 的真实值 `alipays` / `alipayqr`；`ProbeResult` 用 `dataclass`，`__post_init__` 校验 status。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_probe_common -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'probe.lib.probe_common'`。

- [ ] **Step 3: 实现 `probe/lib/probe_common.py`**

按 Interfaces 的签名实现。`run_hdc` 用 `subprocess.run(["hdc", "-t", DEVICE_ID, "shell", shell_cmd], ...)` 并捕获 `subprocess.TimeoutExpired` / `TimeoutError` 返回 `(-1, "")`；`parse_kv_lines` 用逐行正则 `'"<key>"\s*:\s*"([^"]*)"'`；`ProbeResult` 为 `dataclass`，`__post_init__` 校验 `status ∈ {"OK","EMPTY","SKIPPED","ERROR"}`。不引入第三方库。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（6 tests）。

- [ ] **Step 5: 补充边界测试并跑过**

在 `test_probe_common.py` 的 `TestParseKvLines` 增加：
```python
    def test_malformed_line_is_ignored(self):
        self.assertEqual(parse_kv_lines('"scheme" = alipays', "scheme"), [])
```
Run: 同 Step 2。Expected: PASS（7 tests）。

- [ ] **Step 6: 写 `probe/README.md` 骨架**

内容固定三节：`# 预研探针（throwaway）` / `## 纪律`（逐条抄 Global Constraints 里「探针全部为 throwaway」起的四条） / `## 复现入口`（按 Tech Stack 的固定调用形式，写 `python -I -m unittest discover -s probe -t . -p "test_*.py" -v` 与各 `python -I probe/<script>.py`，此时只填本任务已存在的脚本）。同时创建 `probe/__init__.py` 与 `probe/results/` 目录。

- [ ] **Step 7: 记录产物**

校验 `probe/__init__.py`、`probe/lib/__init__.py`、`probe/lib/probe_common.py`、`probe/lib/test_probe_common.py`、`probe/README.md` 均存在且测试为 7 PASS。不执行 git 命令。

---

### Task 2: L1 shortcut 参数结构化 `scan_shortcut_params.py`

**Files:**
- Create: `probe/scan_shortcut_params.py`
- Test: `probe/test_scan_shortcut_params.py`
- Create: `probe/results/shortcut_params.json`（由脚本生成）

**Interfaces:**
- Consumes: Task 1 的 `run_hdc`, `parse_kv_lines`, `write_json`, `ProbeResult`, `DEVICE_ID`。
- Produces:
  - `SHORTCUT_BUNDLES: list[str]` — spec 附录 A 中 17 个有 shortcut 的 bundle（完整列表见附录 A）
  - `parse_shortcut_block(text: str) -> list[dict]` — 解析 `bm dump -n <b> -s` 输出，返回 `[{"id": str, "parameters": dict, "targetClass": str, "targetModule": str}]`
  - `scan_all(bundles: list[str]) -> dict[str, list[dict]]`

- [ ] **Step 1: 写失败测试**

`probe/test_scan_shortcut_params.py`（fixture 用真机实测的支付宝片段，写死在测试里，不联网）：
```python
import unittest
from probe.scan_shortcut_params import parse_shortcut_block

FIXTURE = '''
"shortcut":
{
    "id": "scan",
    "intents": [
        {
            "parameters": {
                "appId": "10000007",
                "sceneCode": "KF_CHANGSHANG",
                "source": "Harmony3DTouch"
            },
            "targetBundle": "com.alipay.mobile.client",
            "targetClass": "EntryAbility",
            "targetModule": "entry"
        }
    ]
}
'''
class TestParseShortcut(unittest.TestCase):
    def test_extracts_id_and_parameters(self):
        got = parse_shortcut_block(FIXTURE)
        self.assertEqual(got[0]["id"], "scan")
        self.assertEqual(got[0]["parameters"]["appId"], "10000007")
        self.assertEqual(got[0]["targetClass"], "EntryAbility")

    def test_bundle_without_shortcuts_yields_empty_list(self):
        self.assertEqual(parse_shortcut_block("shortcuts:\n"), [])
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_scan_shortcut_params -v`
Expected: FAIL（`parse_shortcut_block` 未定义）。

- [ ] **Step 3: 实现 `probe/scan_shortcut_params.py`**

`parse_shortcut_block` 用标准库 `json` 不可行（`bm dump -s` 输出是多个 JSON 对象拼文本，非单一合法 JSON），故按 `"shortcut":` 分块、逐块 `json.loads("{" + ... + "}")` 或用正则提取 `id` / `targetClass` / `targetModule` / `parameters` 键值；实现者按 fixture 选一种，以测试通过为准。`scan_all` 对每个 bundle 调 `run_hdc(f"bm dump -n {b} -s")`，空输出记 `ProbeResult(b, "L1", "EMPTY", "")` 并继续；`__main__` 写 `probe/results/shortcut_params.json`。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（2 tests）。

- [ ] **Step 5: 真机执行并核验**

Run: `cd E:/CodeE/vibe51/Stargate && python -I probe/scan_shortcut_params.py`
Expected: `probe/results/shortcut_params.json` 生成；用 `python -I -c "import json;d=json.load(open('probe/results/shortcut_params.json'));print(len(d), d['com.alipay.mobile.client'][0]['id'])"` 核验支付宝首个 shortcut 为 `scan`、参数含 `appId=10000007`，且与 spec 附录 A 的 17 个 bundle 对齐。

- [ ] **Step 6: 补 `probe/README.md` 的「L1 探针」小节并**记录产物

校验 4 个文件存在、测试 2 PASS、JSON 可解析且含 17 个 bundle。不执行 git 命令。

---

### Task 3: 执行层样本清单与降级序列定义 `launch_matrix.py`（骨架）

**Files:**
- Create: `probe/launch_matrix.py`
- Test: `probe/test_launch_matrix.py`

**Interfaces:**
- Consumes: Task 1 的 `run_hdc`, `ProbeResult`, `write_tsv`；Task 2 的 `shortcut_params.json`。
- Produces:
  - `SAMPLES: list[dict]` — spec §2.3 的代表样本，每项 `{"bundle", "category", "route", "kind", "expected"}`，`kind ∈ {"want","deeplink","applinking","shortcut-param","home"}`
  - `build_route_sequence(sample: dict) -> list[str]` — 返回该样本的 `aa start` 参数序列，最后一項恒为回退首页的显式 ability 启动
  - `classify_exit(code: int, stdout: str) -> str` — 返回 `OK` / `SKIPPED` / `ERROR`

- [ ] **Step 1: 写失败测试**

`probe/test_launch_matrix.py`：
```python
import unittest
from probe.launch_matrix import build_route_sequence, classify_exit

class TestBuildRouteSequence(unittest.TestCase):
    def test_last_route_is_home_fallback(self):
        seq = build_route_sequence({"bundle": "com.alipay.mobile.client",
                                    "kind": "deeplink", "route": "alipays://platformapi/startapp"})
        self.assertEqual(seq[-1], "-a EntryAbility -b com.alipay.mobile.client")
        self.assertTrue(seq[0].startswith("-U "))

    def test_shortcut_param_uses_ps_flags(self):
        seq = build_route_sequence({"bundle": "com.tencent.wechat",
                                    "kind": "shortcut-param",
                                    "route": '{"shortCutKey": "shortCutScan"}'})
        self.assertIn("--ps shortCutKey shortCutScan", seq[0])

class TestClassifyExit(unittest.TestCase):
    def test_unavailable_device_marks_skipped(self):
        self.assertEqual(classify_exit(-1, ""), "SKIPPED")
```
（真机值取自 spec §2.1 / 附录 A：支付宝 `alipays`、微信 `shortCutKey=shortCutMyQrCode` / `shortCutScan`。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_launch_matrix -v`
Expected: FAIL（`build_route_sequence` 未定义）。

- [ ] **Step 3: 实现 `probe/launch_matrix.py` 的纯函数与 `SAMPLES`**

`SAMPLES` 至少覆盖 spec §2.3 七个品类各一个：支付宝 `scan`(L1)、微信 `id_scan`(L1)、高德 `systemnav://navigation`(L2/L3)、12306 `cn.12306.uppayment`(L3)、京东 `openjd`(L3)、WPS `ksowps`(L3)、个税 `etax`(L3)。`build_route_sequence` 按 `kind` 生成：`deeplink` → `-U <route>`；`shortcut-param` → `-a EntryAbility -b <bundle> --ps <k> <v> ...`；`want` → `-A <action> -U <uri>`；末尾恒追加 `-a EntryAbility -b <bundle>`。本任务**不执行任何 `aa start`**。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（3 tests）。

- [ ] **Step 5: 补 README「执行层探针」小节并记录产物**

校验文件存在、测试 3 PASS、`SAMPLES` 长度为 7 且每项含 5 个键。不执行 git 命令。

---

### Task 4: 执行层真机落点验证 + L5′ 控件树判定

**Files:**
- Create: `probe/uitest_layout.py`
- Test: `probe/test_uitest_layout.py`
- Modify: `probe/launch_matrix.py`（新增 `run_matrix()` 与 `__main__`）
- Test: `probe/test_launch_matrix.py`（追加落点分类测试）
- Create: `probe/results/launch_matrix.tsv`（由脚本生成）

**Interfaces:**
- Consumes: Task 1 的 `run_hdc`, `write_tsv`, `ProbeResult`；Task 3 的 `SAMPLES`, `build_route_sequence`, `classify_exit`。
- Produces:
  - `uitest_layout.dump_layout(device: str) -> dict` — `hdc -t <dev> shell "uitest dumpLayout -p /data/local/tmp/_layout_probe.json"` 后 `cat` 取回，解析 JSON
  - `uitest_layout.classify_layout(layout: dict, expected: str) -> str` — 返回 `TARGET` / `HOME` / `UNKNOWN`（Review Focus #2）
  - `launch_matrix.run_matrix(samples: list[dict]) -> list[ProbeResult]`

- [ ] **Step 1: 写失败测试（控件树判定）**

`probe/test_uitest_layout.py`：
```python
import unittest
from probe.uitest_layout import classify_layout

class TestClassifyLayout(unittest.TestCase):
    def test_classify_layout_home_vs_target(self):
        home = {"children": [{"text": "首页", "type": "Text"}]}
        target = {"children": [{"text": "收付款", "type": "Text"}]}
        self.assertEqual(classify_layout(home, "收付款"), "HOME")
        self.assertEqual(classify_layout(target, "收付款"), "TARGET")

    def test_empty_layout_is_unknown(self):
        self.assertEqual(classify_layout({}, "收付款"), "UNKNOWN")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_uitest_layout -v`
Expected: FAIL（`classify_layout` 未定义）。

- [ ] **Step 3: 实现 `probe/uitest_layout.py`**

`dump_layout` 复用本机已有轮子机制（spec §4.5）：确认 `/system/bin/uitest start-daemon singleness &` 已在跑（用 `netstat -anp | grep 8012` 判断），否则启动；`uitest_agent` 按本机 `HapTest/res/uitest/uitest_agent_v1.0.8.so` 路径，需要时 `hdc file send` 到 `/data/local/tmp/agent.so`；`hdc fport` 转发 `tcp:8012`。`classify_layout` 递归遍历 `children`，命中 `expected` 文本返回 `TARGET`；命中「首页 / 主页 / Home」返回 `HOME`；否则 `UNKNOWN`。**只读控件树，不注入任何点击**（L5′ 在预研中仅用于落点判定）。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（2 tests）。

- [ ] **Step 5: 实现 `run_matrix()` 与 `__main__`**

每个样本：`run_hdc(f"aa start {arg}")` 逐条尝试 → `classify_exit`；成功后再 `dump_layout` + `classify_layout` 判落点；`HOME` 视为降级命中并继续尝试下一 route；最终仍非 `TARGET` 则执行 `-a EntryAbility -b <bundle>` 回退首页并记 `FALLBACK_HOME`。每个样本结束 `run_hdc(f"aa force-stop {bundle}")` 复原。结果写 `probe/results/launch_matrix.tsv`，表头固定：`bundle,category,layer,route,exit,layout,landing,note`。`run_hdc` 返回 `(-1, "")` 时该样本记 `ProbeResult(bundle, layer, "SKIPPED", "device unavailable")`，不抛异常。脚本顶部按 Tech Stack 约定注入 `sys.path`。

- [ ] **Step 6: 追加跳过分支测试并跑过**

在 `probe/test_launch_matrix.py` 追加（用 `unittest.mock.patch`，不依赖真机）：
```python
from unittest.mock import patch
from probe.launch_matrix import run_matrix, SAMPLES

class TestRunMatrix(unittest.TestCase):
    def test_unavailable_device_marks_all_skipped(self):
        with patch("probe.launch_matrix.run_hdc", return_value=(-1, "")):
            results = run_matrix(SAMPLES[:1])
        self.assertTrue(all(r.status == "SKIPPED" for r in results))
```
Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_launch_matrix -v`
Expected: PASS（4 tests：Task 3 的 3 个 + 本步 1 个）。

- [ ] **Step 7: 列清单后再真机执行**

先打印 `SAMPLES` 清单（会真实拉起 7 个 App）并确认；随后 Run: `cd E:/CodeE/vibe51/Stargate && python -I probe/launch_matrix.py`
Expected: `probe/results/launch_matrix.tsv` 生成 7 行，`landing ∈ {TARGET, FALLBACK_HOME, UNKNOWN, SKIPPED}`；执行后 `hdc -t 5KPBB25927200695 shell "bm dump -a"` 仍可正常返回（设备未被改坏）。

- [ ] **Step 8: 补 README「落点判定」小节并记录产物**

校验 `probe/uitest_layout.py`、`probe/test_uitest_layout.py`、`probe/launch_matrix.py`、`probe/test_launch_matrix.py` 存在；`-k test_uitest_layout` 2 PASS、`-k test_launch_matrix` 4 PASS；TSV 为 7 行且表头一致。不执行 git 命令。

---

### Task 5: L4 逆向实证 `rea_route_probe.py`

**Files:**
- Create: `probe/rea_route_probe.py`
- Test: `probe/test_rea_route_probe.py`
- Create: `probe/results/rea_routes.json`（由脚本生成）

**Interfaces:**
- Consumes: Task 1 的 `run_host`, `write_json`, `ProbeResult`。REA MCP 由执行者手工调用（见 Step 5），脚本只消费其产物路径。
- Produces:
  - `HAP_SAMPLES: list[str]` — 本机样本，取 `C:\Users\32147\Downloads\aa\entry-default-signed.hap` 与 `C:\Users\32147\Downloads\Legado-V1.0.2.1-251130-unsigned-signed.hap`
  - `extract_hap(hap_path: str, out_dir: str) -> dict` — `unzip -o -q` 到 `out_dir`，返回 `{"module_json": ..., "main_pages": ..., "source_maps": ..., "modules_abc": ..., "missing": [...]}` 各文件是否存在
  - `collect_route_hints(out_dir: str, inventory: dict) -> dict` — 从 `module.json` 提取 `abilities[].skills[].uris` 的 scheme/host/path，从 `main_pages.json` 提取 `src`，从 `sourceMaps.map` 提取 `.ets` 路径，从 `modules.abc` 用 `strings -n 5` 过滤 `page|router|url|scheme|ability` 关键词
  - `build_partial_result(hap_path: str, inventory: dict) -> dict` — Review Focus #4：缺文件时返回带 `missing` 的部分结果而非抛异常

- [ ] **Step 1: 写失败测试**

`probe/test_rea_route_probe.py`：
```python
import unittest
import tempfile, pathlib, json
from probe.rea_route_probe import build_partial_result, collect_route_hints

EMPTY_INV = {"module_json": False, "main_pages": False, "source_maps": False,
             "modules_abc": False, "missing": []}

class TestMissingFiles(unittest.TestCase):
    def test_missing_abc_produces_partial_result(self):
        inv = dict(EMPTY_INV, module_json=True, main_pages=True,
                   missing=["ets/modules.abc", "ets/sourceMaps.map"])
        got = build_partial_result("fake.hap", inv)
        self.assertEqual(got["status"], "PARTIAL")
        self.assertIn("ets/modules.abc", got["missing"])

class TestCollectHints(unittest.TestCase):
    def test_extracts_pages_from_main_pages(self):
        d = tempfile.mkdtemp()
        pathlib.Path(d, "resources/base/profile").mkdir(parents=True)
        pathlib.Path(d, "resources/base/profile/main_pages.json").write_text(
            json.dumps({"src": ["pages/Index"]}), encoding="utf-8")
        inv = dict(EMPTY_INV, main_pages=True, missing=[
            "ets/modules.abc", "ets/sourceMaps.map", "module.json"])
        got = collect_route_hints(d, inv)
        self.assertIn("pages/Index", got["pages"])
```
（`collect_route_hints` 只读 `inventory` 标为 True 的文件；`main_pages.json` 位于 HAP 内 `resources/base/profile/`。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_rea_route_probe -v`
Expected: FAIL（函数未定义）。

- [ ] **Step 3: 实现 `probe/rea_route_probe.py`**

`extract_hap` 用 `run_host(["unzip", "-o", "-q", hap_path, "-d", out_dir])`；下载/样本 HAP 一律解压到**独立空目录**（Global Constraints 的不可信数据规则），脚本本身放在 `probe/` 不与之同目录。`collect_route_hints` 对不存在的文件跳过并累积到 `missing`。`build_partial_result` 在 `missing` 非空时返回 `status="PARTIAL"`。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（2 tests）。

- [ ] **Step 5: REA 清点 + 脚本实证（分两步）**

5a. 执行者用 REA MCP：`open_binary` 打开 `HAP_SAMPLES[0]` → `inspect_artifact(detail="complete")` 记录 `module.json` / `ets/modules.abc` / `ets/sourceMaps.map` / `resources/base/profile/main_pages.json` 的路径 → `close_binary`。对 `HAP_SAMPLES[1]` 重复一次。把两次清点结果记入 `probe/results/rea_routes.json` 的 `rea_inventory` 字段。
5b. Run: `cd E:/CodeE/vibe51/Stargate && python -I probe/rea_route_probe.py`
Expected: `probe/results/rea_routes.json` 含 `rea_inventory`、`hints`、`status`；两个样本都产出 `pages` 或 `schemes` 至少一类线索，且 `missing` 字段如实列出。

- [ ] **Step 6: xpanda / dayu 可用性评估（文档级，不改代码）**

在 `probe/README.md` 增「L4 工具链」小节，按 spec §5.2 记录：`asmjmp0/xpanda`（Apache-2.0）、`hx1997/dayu`（AGPL-3.0，**仅作工具不并入产品**）；注明本阶段仅评估、不安装、不执行反编译，REA 的 `list_strings` 不支持 HAP archive 的原因（Ghidra 未配置 / Hopper 不支持 win32 / IDA 未配置 / Kuna 未配置）。

- [ ] **Step 7: 记录产物**

校验 3 个文件存在、测试 2 PASS、JSON 含 `rea_inventory` 与两个样本。不执行 git 命令。

---

### Task 6: 调研笔记成文 + 仓库核实辅助

**Files:**
- Create: `docs/research/github-wheel-survey.md`
- Create: `docs/research/ios-paradigm-reverse.md`
- Create: `docs/research/fallback-boundary.md`
- Create: `probe/verify_github_repos.py`
- Test: `probe/test_verify_github_repos.py`

**Interfaces:**
- Consumes: Task 1 的 `write_json`；spec §5.2 的项目清单与 §4.4/§4.5 的 L5/L5′ 结论。
- Produces:
  - `REPOS: list[str]` — spec §5.2 表格中的 10 个 canonical 仓库全名
  - `verify_repo(full_name: str, timeout: int = 20) -> dict` — `curl -s --max-time <t> https://api.github.com/repos/<full_name>`，解析出 `{full_name, license, stars, pushed_at, archived}`；HTTP 非 200 / 超时 / 限流 → 返回 `{"full_name": ..., "status": "UNVERIFIED", "reason": ...}`（Review Focus #5）
  - `docs/research/*.md` 三份笔记

- [ ] **Step 1: 写失败测试**

`probe/test_verify_github_repos.py`：
```python
import unittest
from unittest.mock import patch
from probe.verify_github_repos import verify_repo

class TestVerifyRepo(unittest.TestCase):
    def test_verify_repo_marks_rate_limited(self):
        with patch("probe.verify_github_repos.run_host",
                   return_value=(0, '{"message":"API rate limit exceeded"}')):
            got = verify_repo("blacktop/ipsw")
        self.assertEqual(got["status"], "UNVERIFIED")

    def test_verify_repo_reads_license(self):
        body = ('{"full_name":"blacktop/ipsw","license":{"spdx_id":"MIT"},'
                '"stargazers_count":3870,"pushed_at":"2026-11-06T00:00:00Z","archived":false}')
        with patch("probe.verify_github_repos.run_host", return_value=(0, body)):
            got = verify_repo("blacktop/ipsw")
        self.assertEqual(got["license"], "MIT")
```
（`run_host` 由 `probe.lib.probe_common` 导入到本模块命名空间，patch 路径按此写。）

- [ ] **Step 2: 跑测试确认失败**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_verify_github_repos -v`
Expected: FAIL（`verify_repo` 未定义）。

- [ ] **Step 3: 实现 `probe/verify_github_repos.py`**

`verify_repo` 检查返回体是否含 `"message"` 或缺少 `full_name` → `UNVERIFIED`；否则取 `license.spdx_id`（可能为 `null` → 记 `"NONE"`）、`stargazers_count`、`pushed_at[:10]`、`archived`。`__main__` 遍历 `REPOS` 写 `probe/results/github_verify.json`。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（2 tests）。

- [ ] **Step 5: 联网核实并成文 `github-wheel-survey.md`**

Run: `cd E:/CodeE/vibe51/Stargate && python -I probe/verify_github_repos.py`
Expected: `probe/results/github_verify.json` 生成。笔记按 spec §5.2 表格成文，每项目标注「核实状态 / License / 最后提交 / 可否复用」；单列一节写「镜像域名陷阱」「无 License / 已归档项目不可复用」「未找到鸿蒙功能直达聚合启动器与 Smart Stack 排序开源实现」三项局限。

- [ ] **Step 6: 成文 `ios-paradigm-reverse.md`**

按 spec §5.2 的主动逆向路径成文：`blacktop/ipsw` 拉 Simulator Runtime `.dmg` / IPSW → dyld_shared_cache → 定位 App Library / Siri Suggestions / Proactive 私有框架 → REA 静态逆向 Mach-O。**仅文档推演，本阶段不下载 .dmg / IPSW**（体积大且属不可信外部数据）；明确写「不需真机、不需运行模拟器」、iOS 侧可参考的只是 App Intents donation / `recommendations()` 机制、排序逻辑自行设计（spec §3.1）。

- [ ] **Step 7: 成文 `fallback-boundary.md`**

把 spec §4.4（注入/Hook、无障碍模拟点击的机制、可行上限、绕过思路调研、代价与合规冲突、结论定调表）与 §4.5（L5′ uitest 通道来源核实、机制、无需 root、`@ohos.UiTest` 测试专用 syscap 边界、本机六套轮子）整理成独立笔记；开头照抄 spec §4.4 的「范围声明」，结尾照抄「技术储备、非产品路径」结论。

- [ ] **Step 8: 记录产物**

校验 6 个文件存在、测试 2 PASS、`github_verify.json` 含 10 项且每项有 `status`。不执行 git 命令。

---

### Task 7: 汇总可行性结论与最终交付校验

**Files:**
- Modify: `docs/superpowers/specs/2026-11-07-harmony-atomic-function-panel-design.md`（仅新增 §7「预研实证补录」，不改既有章节）
- Modify: `probe/README.md`（补全全部探针的复现入口）
- Create: `probe/results/FINAL_REPORT.md`

**Interfaces:**
- Consumes: Task 2 `shortcut_params.json`、Task 4 `launch_matrix.tsv`、Task 5 `rea_routes.json`、Task 6 `github_verify.json` 与三份笔记。
- Produces: `probe/results/FINAL_REPORT.md`（汇总表）与 spec §7。

- [ ] **Step 1: 写汇总校验测试**

新建 `probe/test_final_report.py`（本任务是交付校验，非 TDD 红灯）：
```python
import unittest, os, csv, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

class TestEvidenceFiles(unittest.TestCase):
    def test_all_evidence_files_exist_and_nonempty(self):
        for p in ["probe/results/shortcut_params.json",
                  "probe/results/launch_matrix.tsv",
                  "probe/results/rea_routes.json",
                  "probe/results/github_verify.json"]:
            self.assertGreater((ROOT / p).stat().st_size, 0)

    def test_launch_matrix_has_seven_rows(self):
        with (ROOT / "probe/results/launch_matrix.tsv").open(encoding="utf-8") as f:
            rows = list(csv.reader(f))
        self.assertEqual(len(rows) - 1, 7)

    def test_research_notes_exist(self):
        for p in ["docs/research/github-wheel-survey.md",
                  "docs/research/ios-paradigm-reverse.md",
                  "docs/research/fallback-boundary.md"]:
            self.assertTrue((ROOT / p).is_file())
```

- [ ] **Step 2: 跑校验测试**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -k test_final_report -v`
Expected: PASS（3 tests）。若某项失败，回到对应 Task 补齐证据后重跑，不要在测试里放宽断言。

- [ ] **Step 3: 全量回归**

Run: `cd E:/CodeE/vibe51/Stargate && python -I -m unittest discover -s probe -t . -p "test_*.py" -v`
Expected: 全部 PASS（Task1 7 + Task2 2 + Task3 3 + Task4 (2+1) + Task5 2 + Task6 2 + Task7 3 = **22 tests**）。

- [ ] **Step 4: 写 `FINAL_REPORT.md` 与 spec §7**

`FINAL_REPORT.md` 用一张表汇总：层级 / 数据源 / 实测样本数 / 命中数 / 失败或降级数 / 结论，数据来自上述四个结果文件；另列「与 spec §6 六条结论的逐条印证 / 修正」。spec §7 只追加一节，写明本轮补齐了哪三块实证、新增了哪些证据文件，**不修改 §0–§6 与附录 A/B 的任何既有内容**。

- [ ] **Step 5: 最终交付校验**

逐项确认：① 全部探针脚本在 `probe/`、笔记在 `docs/research/`；② 22 个单测 PASS；③ 四个证据文件非空且可解析；④ `docs/research/` 三份笔记齐备；⑤ **目录中没有产品工程、没有 `hvigor/` 目录、没有 `.ets`/`.hap` 产品文件**（`probe/results/` 下的 HAP 解压产物除外，且须在独立临时目录）；⑥ 未执行任何 `git` 命令、未 `git init`。把校验结果记入 `FINAL_REPORT.md` 末尾。

---

## 执行后的下一步（不属于本计划）

本计划完成 = 「预研」阶段收口。若要进入产品开发，按 spec §0.6 把 S1–S7 拆成子 spec，各自再走 brainstorming → spec → plan → 实现周期；本计划不覆盖产品开发。

## Self-Review 记录

1. **Spec coverage**：§0/§1/§3/§6 为设计文档内容，无需代码任务；§2.3 实测矩阵由 Task 2/3/4 覆盖；§4.3 逆向工具链由 Task 5 覆盖；§4.4/§4.5 L5/L5′ 由 Task 6 笔记覆盖；§5.2 GitHub/iOS 调研由 Task 6 覆盖；§5.3 三层验证由 Task 2/4/5 覆盖；§5.4 产品测试策略**不在本计划范围**（spec §5.6 明确不做产品工程），已在「执行后的下一步」标注；§5.5 风险登记由 Global Constraints 与 Review Focus 覆盖；§5.6 交付物由 Task 6/7 覆盖。无遗漏。
2. **Step scan**：每个代码步骤给出签名 + 文件 + 固定值；无「TBD / handle edge cases」类空行；算法体只在 `parse_shortcut_block` 与 `classify_layout` 处留出实现选择并以测试为准。所有 `Run:` 命令已在 Windows + Python 3.12 上实测过形式有效性（`-I` 下 `PYTHONPATH` 无效、仅 `discover -t .` 可用）。
3. **Type consistency**：`ProbeResult(bundle, layer, status, detail)`、`parse_kv_lines(text, key)`、`run_hdc(shell_cmd, timeout)`、`run_host(cmd, timeout)`、`write_tsv(path, header, rows)`、`write_json(path, obj)`、`parse_shortcut_block(text)`、`scan_all(bundles)`、`build_route_sequence(sample)`、`classify_exit(code, stdout)`、`run_matrix(samples)`、`dump_layout(device)`、`classify_layout(layout, expected)`、`extract_hap(hap_path, out_dir)`、`collect_route_hints(out_dir, inventory)`、`build_partial_result(hap_path, inventory)`、`verify_repo(full_name, timeout)` 在前后任务中一致；`SAMPLES` 为 `list[dict]`，`SHORTCUT_BUNDLES` / `REPOS` / `HAP_SAMPLES` 为 `list[str]`。所有测试用包内绝对导入 `from probe.<module> import ...`（`discover -t .` 下可用）。
4. **Review Focus**：5 条逐条钉在具名测试上 —— #1 `test_missing_bundle_returns_empty_result` / `test_bundle_without_shortcuts_yields_empty_list`；#2 `test_classify_layout_home_vs_target`；#3 `test_run_cmd_timeout_returns_error_result` / `test_unavailable_device_marks_all_skipped`；#4 `test_missing_abc_produces_partial_result`；#5 `test_verify_repo_marks_rate_limited`。
5. **Proportion**：spec 429 行，本计划约 300 行；代码体仅出现在测试断言与少量算法说明中，未转录程序。本计划 7 个任务共 22 个单测，全部为离线 fixture / mock，只有 Task 4 Step 7 需要真机。
