---
ticket: T-0001-merge-sort
type: ticket
from: claude
date: 2026-11-03T05:06:10-08:00
branch: tkt/T-0001-merge-sort
base: 31bbb49cbf23b356724a3c31206901a9c3bda66d
kind: implementation   # implementation | research | docs
---

# 实施工单 T-0001-merge-sort：稳定归并排序库 sortkit + 命令行入口（真机试点）

> 规则：COLLABORATION.md §4.1。质量线：**Codex 不追问就能开工**。
> 这是协作流程的**真机试点**：除了代码本身，流程里任何不顺手的地方也请记下来（见 §10）。

## 1. 目标

交付一个只依赖 Python 标准库的小型排序库 `sortkit`：一个与内置 `sorted()` **语义一致**的稳定归并排序函数，加一个命令行入口。

## 2. 背景与约束

- 项目参数见 `docs/design/project-profile.md`：Python ≥ 3.8，**只用标准库**，不引入任何第三方包。
- **核心排序不得借用现成排序**：`sortkit/` 下的代码禁止调用 `sorted()`、`list.sort()`、`heapq`、`bisect`。（测试代码可以用 `sorted()` 做对照，那是下一阶段的事。）
- 代码风格：PEP 8；公开函数带类型注解和 docstring（中英文均可）。
- 所有命令在仓库根目录、Windows cmd 下运行。若你机器上的命令是 `py -3` 而不是 `python`，照此替换并在报告中注明。

## 3. 范围

**做：**

- `sortkit` 包：排序函数 + 命令行入口（见 §4）

**不做（明确排除）：**

- 不写正式测试套件。`tests/` 留到测试工单阶段，按 Claude 的测试方案编写。
- 不实现其他排序算法，不加打包配置（`setup.py` / `pyproject.toml`），不改 `sortkit/` 以外的产品代码。

## 4. 任务分解

| 编号 | 说明 | 目标路径 | 依赖 | 自验方式 |
|---|---|---|---|---|
| K1 | `merge_sort` 函数，契约见下 | `sortkit/core.py` | — | §6 的 A1–A4 |
| K2 | 包入口：`from .core import merge_sort`，`__all__ = ["merge_sort"]` | `sortkit/__init__.py` | K1 | A1 |
| K3 | 命令行入口（argparse），契约见下 | `sortkit/__main__.py` | K1 | A5、A6 |

**K1 `merge_sort` 契约**

```python
def merge_sort(items: Iterable[T], *, key: Callable[[T], Any] | None = None,
               reverse: bool = False) -> list[T]: ...
```

（3.8 下可用 `typing.Optional` / `List` 等写法，以能在 3.8 运行为准。）

1. 接受任意可迭代对象（list、tuple、生成器……），**返回新的 list，不修改入参**。
2. **稳定**：比较结果相等的元素，保持它们在输入中的相对顺序。
3. `reverse=True` 时结果与 `sorted(items, key=key, reverse=True)` **完全一致**。也就是说，降序时相等元素仍保持原相对顺序。⚠️ "先升序、再整体反转"的写法会打乱相等元素的顺序，**不符合要求**。
4. `key` 为 `None` 时直接比较元素；否则**每个元素的 key 只计算一次**（n 个元素，key 恰好调用 n 次）。
5. 比较只用 `<`（与内置 `sorted` 一致）。元素之间无法比较时，让 Python 自然抛出 `TypeError`，不要吞掉或改写。
6. 时间复杂度 O(n log n)。不得因递归过深失败：n = 1,000,000 时不能出现 `RecursionError`。递归实现的深度约为 log₂n，自然满足；也可以用自底向上的迭代实现。在报告里说明选了哪种、为什么。

**K3 命令行契约**：`python -m sortkit [-r | --reverse]`

- 从 **stdin** 读取以任意空白（空格、制表符、换行）分隔的**整数**（可以是负数）。
- 输出排好序的整数：空格分隔、一行、末尾换行；`-r` / `--reverse` 降序。
- 输入为空（或只有空白）：输出一个空行，退出码 0。
- 遇到不是整数的词（第一个出错的词记为 `<tok>`）：**stdout 不输出任何内容**；stderr 输出一行 `error: invalid integer: <tok>`；退出码 **2**。

## 5. 接口与契约变更

新增公开 API `sortkit.merge_sort`；新增命令行 `python -m sortkit`。仓库里原本没有产品代码，所以没有兼容性问题。

## 6. 验收标准（必须可判定）

在仓库根目录、cmd 下执行：

| 编号 | 判据（命令 → 期望结果） | 无信息基线（被测代码"不干活"时会怎样） |
|---|---|---|
| A1 | `python -c "from sortkit import merge_sort; print(merge_sort([3, 1, 2]))"` → `[1, 2, 3]` | 函数原样返回 `list(items)` 时输出 `[3, 1, 2]` → 不满足 |
| A2 | `python -c "from sortkit import merge_sort; print(merge_sort([(1, 'b'), (0, 'x'), (1, 'a')], key=lambda t: t[0]))"` → `[(0, 'x'), (1, 'b'), (1, 'a')]` | 原样返回时 `(1, 'b')` 在最前 → 不满足；不稳定排序可能把 `(1, 'a')` 排在 `(1, 'b')` 前 → 不满足 |
| A3 | 同 A2 但加 `reverse=True` → `[(1, 'b'), (1, 'a'), (0, 'x')]` | "先升序再反转"得到 `[(1, 'a'), (1, 'b'), (0, 'x')]` → 不满足 |
| A4 | `python -c "from sortkit import merge_sort; a = [3, 1, 2]; merge_sort(a); print(a)"` → `[3, 1, 2]` | 原地排序的实现会输出 `[1, 2, 3]` → 不满足 |
| A5 | `echo 3 -1 2 \| python -m sortkit` → `-1 2 3`；`echo 3 -1 2 \| python -m sortkit -r` → `3 2 -1` | 没有 `__main__.py` 时报 `No module named sortkit.__main__` → 不满足 |
| A6 | `echo 3 x 2 \| python -m sortkit` → stdout 为空；stderr 为 `error: invalid integer: x`；`echo %ERRORLEVEL%` 为 `2` | 不处理时抛 `ValueError` 回溯、退出码 1 → 不满足 |
| A7 | `findstr /L /N "sorted( .sort( heapq bisect" sortkit\*.py` → **无任何输出** | — |

（cmd 里管道符直接写 `|`。表格中的 `\|` 只是 Markdown 转义。）

A7 是纯文本检查：`sortkit/` 的**注释和 docstring 里也不要出现**这几个字样，需要提到时写 "built-in sort" 之类的说法，否则会误报。

## 7. 自测要求

- 交付前把 A1–A7 全部跑一遍，把**命令和真实输出原样**贴进 `impl-report` 的"自测"一节。
- 注明 `python --version` 的输出。
- 另外自己试几组边界输入（空列表、单元素、全相同、已排序、逆序），在报告里简述结果。

## 8. 风险与待确认

- 同事机器没有 Python ≥ 3.8 → 不要自行安装其他版本或第三方工具，走质询（`query`，类型 `blocker`）。
- 对契约有任何疑问（尤其 §4 第 3、4 条）→ 先质询，不要猜。

## 9. 参考资料

- Python 文档 *Sorting Techniques*：稳定性、`key`、`reverse` 的语义。
- `docs/design/project-profile.md`：构建与测试命令。

## 10. 试点附加要求：流程反馈

在 `impl-report` 的"遗留风险 / 已知问题"之后加一小节 **"流程反馈"**：这一轮 `inbox` / `open` / `msg` / `send`、AGENTS.md、技能里**任何不顺手、看不懂、报错的地方**，原样记下来（命令 + 输出）。没有就写"无"。
