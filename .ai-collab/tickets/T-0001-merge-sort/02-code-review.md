---
ticket: T-0001-merge-sort
type: code-review
from: claude
date: 2026-11-03T05:52:16-08:00
reviewed_head: 139cfc89261f0d95a60beca76d8570c2464707cc
tool: /code-review          # 全程仅此一轮（COLLABORATION.md §4.3）
verdict: fail
---

# 代码审查 T-0001

审查范围：`origin/main...139cfc89`（`sortkit/` 三个文件，共 105 行；不含 `.ai-collab/tickets/`）

## 1. 结论

**fail：只有 1 个必改项（F1），在命令行入口 `sortkit/__main__.py`。排序核心 `merge_sort` 没有问题。**

`merge_sort` 是对的，实现也很干净。Claude 在本机做了独立核对：1640 组随机用例（长度 0–39 和 1000，升序 / 降序，元素带原始位置以检验稳定性）与内置排序逐一比对，全部一致；key 每次恰好调用 n 次；不修改入参；不可比较的元素会原样抛出 TypeError。impl-report 里 A1–A7 的输出也已在本机复现。

报告写得很好：自测证据完整，偏差与风险如实说明，流程反馈很有价值（见 §6）。

## 2. 发现清单与处置

`/code-review` 共报告 8 条。审查代理不了解项目全貌（工单范围、运行环境、平台惯例），所以 Claude 逐条分诊：**只有确认真实、并且违反契约或会造成实际影响的，才列为必改项。**

| # | 严重度 | 文件:行 | 问题 | 处置 | 理由 |
|---|---|---|---|---|---|
| 1 | major | `__main__.py:17` | `sys.stdin.read()` 按系统区域编码解码，解码失败时没有处理 | **必改 F1** | 中文 Windows 上通过管道读 stdin 时按 GBK 严格解码，输入里有一个 GBK 非法字节（例如从 UTF-8 文件 `type` 进来的内容）就抛 `UnicodeDecodeError`，打印 traceback，**退出码 1**，违反 A6 的错误契约。已用 `PYTHONIOENCODING=gbk:strict` 复现 |
| 2 | minor | `__main__.py:20` | 非 ASCII 词的解析结果取决于控制台编码 | 并入 F1 | F1 统一按 UTF-8 解码后自然解决 |
| 3 | minor | `__main__.py:19-25` | Python 3.11+ 上超过 4300 位的整数被当成非法（`str()` 输出时同样受限） | **可选，不派修复** | 真实存在，但本工具不可能遇到 4300 位以上的整数，实际不影响 |
| 4 | note | `__main__.py:25` | Windows 上输出以 `\r\n` 结尾 | **不采纳** | 审查代理按字节比较 `\n` 得出的结论；Windows 文本模式用 `\r\n` 是平台惯例，契约"末尾换行"已满足。测试方案会规定按文本比较 |
| 5 | note | `__main__.py:13` | argparse 用法错误同样返回退出码 2 | **不采纳** | 退出码 2 表示用法错误是命令行的通用约定，契约没有要求两者区分。测试 A6 时会同时断言 stderr 内容 |
| 6 | note | `__main__.py:25` | 下游提前关闭管道时出现 BrokenPipeError | **可选，不派修复** | 契约没有涉及，不影响本工单的使用场景 |
| 7 | note | `core.py:22` | 不传 `key` 时多维护一份 `keys` 数组 | **可选，不派修复** | 纯性能问题；工单没有性能门限，百万元素 2.6 秒已经够用 |
| 8 | note | `core.py:55-64` | 剩余元素逐个复制；相邻段已有序时仍逐个归并 | **可选，不派修复** | 同上 |

## 3. 必改项（本消息即修复工单）

> 请在 fix-report 里逐条对应编号回应。

- **F1 命令行对任何 stdin 内容都不能出现 traceback**
  - 规定（契约澄清）：stdin **一律按 UTF-8 解码，与控制台代码页无关**（例如读 `sys.stdin.buffer` 后自行解码）。无法解码的字节让它所在的词成为非法词，走 A6 的错误路径：stdout 不输出，stderr 一行 `error: invalid integer: <tok>`，退出码 2。`<tok>` 中无法显示的字符允许用替换字符或转义形式表示。
  - 验证：
    1. `python -c "import sys; sys.stdout.buffer.write(b'3 \x81 2\n')" | python -m sortkit`：stdout 为空，stderr 以 `error: invalid integer: ` 开头，退出码 2，**没有 traceback**。在 cmd 里直接跑一次，再在 `set PYTHONIOENCODING=gbk:strict` 之后跑一次，两次结果相同。
    2. `python -c "import sys; sys.stdout.buffer.write('1 ３ 2\n'.encode('utf-8'))" | python -m sortkit`：输出 `1 2 3`（全角 `３` 按 Python `int()` 规则就是 3）。
    3. A1–A7 重跑，结果不变。

## 4. 可选改进（不阻塞，做不做都行；做了请在 fix-report 里说明）

- 第 3 条：命令行进程内解除整数位数上限（`hasattr(sys, "set_int_max_str_digits")` 为真时设为 0）。
- 第 6、7、8 条。

做了任何改动，都要重跑你那份 1000 组以上的随机对照和百万元素检查，并在报告里贴出结果。

## 5. 契约澄清（Claude 工单写得不够严，以此为准，不要求改代码）

- **什么算合法整数**：Python `int(token)`（十进制）能解析的都算，包括 `+5`、`-0`、`1_000`、全角数字。测试方案会按这个定义编写。
- **换行**：使用平台文本模式的换行（Windows 上是 `\r\n`）。
- **退出码 2**：非法整数和命令行用法错误共用。

## 5b. 建议补充的测试（测试阶段由 Claude 写方案）

- A6 断言 stderr 内容，不只断言退出码。
- 编码：非法字节、UTF-8 全角数字、GBK 严格解码环境。
- 降序稳定性的变异：把降序改成"先升序再反转"，测试必须变红。

## 6. 流程反馈（写给试点复盘，不影响本单）

- 收到。`python -c "..."` 的引号问题、多行命令只执行第一行，都来自你的终端执行层，不是 collab 的问题。改用 `.cmd` 文件中转是可行的做法。复盘时考虑在 AGENTS.md 里加一条"在 Windows 下执行带引号的单行命令时的注意事项"。
- 自测日志放在了被忽略的 `.ai-collab/runs/`、`.ai-collab/tmp/`，Claude 无法复核原文件。**编码阶段这样可以**（报告里已有摘录）；**测试阶段的完整日志必须放进 `docs/testing/T-0001-merge-sort/` 并提交**（协约 §4.7）。
