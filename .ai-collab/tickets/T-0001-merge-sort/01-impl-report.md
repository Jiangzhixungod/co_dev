---
ticket: T-0001-merge-sort
type: impl-report
from: codex
date: 2026-11-03T21:46:10+08:00
---

# 编码完成报告 T-0001-merge-sort

> 规则：COLLABORATION.md §4.2。代码已按原子提交提交到 `tkt/T-0001-merge-sort`；`send` 时脚本会记录 code_head。

## 1. 任务完成情况

| 任务 | 状态（完成 / 部分 / 未做） | 说明 |
|---|---|---|
| K1 | 完成 | 实现稳定归并排序，支持任意可迭代对象、key 和 reverse，返回新列表；每个 key 恰好计算一次，仅使用 `<` 比较。 |
| K2 | 完成 | 导出 merge_sort，设置 __all__。 |
| K3 | 完成 | 使用 argparse 实现整数排序 CLI，支持 -r / --reverse；空输入输出空行；首个非法词写入 stderr，stdout 为空，退出码 2。 |

## 2. 变更文件

| 文件 | 改动 |
|---|---|
| sortkit/core.py | 新增自底向上的稳定归并排序。 |
| sortkit/__init__.py | 新增公开包入口。 |
| sortkit/__main__.py | 新增标准输入整数排序命令行。 |

原子提交：

- `b0b39fc`：`[T-0001] 实现稳定归并排序及公开包入口`（K1、K2）。
- `139cfc8`：`[T-0001] 增加整数排序命令行及非法输入处理`（K3，交付代码 HEAD）。

## 3. 关键设计决定

- 使用自底向上的迭代归并，段宽从 1 倍增到覆盖输入，时间 O(n log n)、额外空间 O(n)，不使用递归，因此不存在递归栈深度限制。
- 先将输入物化为新列表，再按输入顺序缓存 key。包括空输入、单元素在内，每个元素只求 key 一次；后续归并只移动缓存，不再次调用 key。
- 升序仅在 `right_key < left_key` 时取右项，降序仅在 `left_key < right_key` 时取右项。其余情况取左项，因此两个方向都保留等键元素的原相对顺序。
- CLI 完成全部整数转换后才输出。首个 int 转换失败立即写出契约指定的单行错误并返回 2，不会输出部分排序结果。
- 使用 typing.List / Optional 等兼容 Python 3.8 的注解，不引入第三方包或打包配置。

## 4. 自测

环境：Windows，仓库根目录，Windows cmd；实际运行命令为 `python`，无需替换为 `py -3`。下列 A1–A7 命令通过临时 cmd 批处理原样执行，完整本机记录在 `.ai-collab/runs/T-0001-merge-sort/acceptance.txt`（忽略目录，不随 Git 交付；证据完整摘录如下）。

运行时和构建检查：

```text
> python --version
Python 3.11.9
> python -m compileall -q sortkit
```

语法检查无输出，退出码 0。

A1：

```text
> python -c "from sortkit import merge_sort; print(merge_sort([3, 1, 2]))"
[1, 2, 3]
```

A2：

```text
> python -c "from sortkit import merge_sort; print(merge_sort([(1, 'b'), (0, 'x'), (1, 'a')], key=lambda t: t[0]))"
[(0, 'x'), (1, 'b'), (1, 'a')]
```

A3：

```text
> python -c "from sortkit import merge_sort; print(merge_sort([(1, 'b'), (0, 'x'), (1, 'a')], key=lambda t: t[0], reverse=True))"
[(1, 'b'), (1, 'a'), (0, 'x')]
```

A4：

```text
> python -c "from sortkit import merge_sort; a = [3, 1, 2]; merge_sort(a); print(a)"
[3, 1, 2]
```

A5：

```text
> echo 3 -1 2 | python -m sortkit
-1 2 3
> echo 3 -1 2 | python -m sortkit -r
3 2 -1
```

A6（分流到文件，保留原始退出码，stdout 大小以字节计）：

```text
> echo 3 x 2 | python -m sortkit > .ai-collab\runs\T-0001-merge-sort\A6.stdout.txt 2> .ai-collab\runs\T-0001-merge-sort\A6.stderr.txt
> echo %ERRORLEVEL%
2
> type .ai-collab\runs\T-0001-merge-sort\A6.stderr.txt
error: invalid integer: x
> for %F in (.ai-collab\runs\T-0001-merge-sort\A6.stdout.txt) do @echo stdout_size=%~zF
stdout_size=0
```

A7：

```text
> findstr /L /N "sorted( .sort( heapq bisect" sortkit\*.py
> echo %ERRORLEVEL%
1
```

findstr 无任何匹配输出，退出码 1 表示没有匹配项，符合 A7。

补充临时自验：未创建 `tests/` 或正式测试套件。临时检查脚本和输出放在本机忽略目录，覆盖五种边界输入、tuple / 生成器、key 调用次数及顺序、仅支持 `<` 的比较对象、异常原样传播、随机对照、CLI 精确输出、兼容语法和百万元素输入。随机种子为 0；随机对照以标准库内置排序为参照，仅用于临时自验，不进入产品代码。

```text
> set PYTHONIOENCODING=utf-8&& python .ai-collab/tmp/T-0001-extra-checks.py > .ai-collab/runs/T-0001-merge-sort/extra-checks.txt 2>&1
> type .ai-collab\runs\T-0001-merge-sort\extra-checks.txt
边界输入 []：升降序、新列表、输入不变均通过
边界输入 [7]：升降序、新列表、输入不变均通过
边界输入 [4, 4, 4]：升降序、新列表、输入不变均通过
边界输入 [1, 2, 3]：升降序、新列表、输入不变均通过
边界输入 [3, 2, 1]：升降序、新列表、输入不变均通过
tuple 和一次性生成器输入：通过
key 调用次数及顺序：空、单元素、重复元素，两个方向均恰好 n 次
仅支持 < 的元素及 key：两个方向的排序和稳定性均通过
不可比较元素自然抛出 TypeError：'<' not supported between instances of 'str' and 'int'
key 异常原样传播：通过
固定种子随机对照：400 组通过（包含升降序重复键稳定性）
命令行：8 组精确 stdout/stderr/退出码检查通过
A6 文件内容及 A7 禁用 API 文本检查：通过
Python 3.8 语法解析及行长检查：通过（实际运行环境为 Python 3.11.9）
百万元素逆序输入：完整排序、输入不变、无 RecursionError；耗时 2.590 秒
全部临时自验通过
```

补充自验命令退出码 0。百万元素使用 `list(range(1_000_000, 0, -1))`，逐项核对结果为 1 到 1,000,000，检查原列表的首尾不变；该耗时只代表本机这一次运行，不作为性能门限。

```text
> git diff --check
```

无输出，退出码 0。

## 5. 与工单的偏差

无。产品变更仅限 `sortkit/`。未新增正式测试套件、其他算法、依赖或打包配置，未修改受保护路径。

## 6. 遗留风险 / 已知问题

- 实际执行环境为 Python 3.11.9；已用 `ast.parse(..., feature_version=(3, 8))` 检查兼容语法，但未在 Python 3.8 解释器上实跑。
- 本工单只要求实现和自测。正式测试套件、三层测试、main 干净基线与变异演示留待 Claude 的测试工单，当前未执行，不能视为已验收。

## 7. 流程反馈

- `scripts\collab.cmd inbox -As codex`、`open -Ticket T-0001 -As codex`、`msg -Type impl-report -As codex` 均正常。inbox 的本地 main 落后提示与工单开分支不冲突；本轮未改动协作工具。
- 终端执行器直接传递带引号的 `python -c` 时出现额外引号。例如：

  ```text
  > python -c "from sortkit import merge_sort; print(merge_sort([3, 1, 2]))"
    File "<string>", line 1
      "from
      ^
  SyntaxError: unterminated string literal (detected at line 1)
  ```

  改为把完全相同的命令写入本机忽略目录下的 `.cmd`，再在 cmd 中调用，结果即为第 4 节的真实输出。问题发生在 agent 终端命令传参层，不是排序实现或 collab.cmd 的错误。
- 终端执行器的一次多行调用只执行了创建日志目录的第一行，导致临时自验首次读取 A6 日志时报 `FileNotFoundError`。拆为单条 `call .ai-collab\tmp\T-0001-acceptance.cmd > .ai-collab\runs\T-0001-merge-sort\acceptance.txt 2>&1` 后正常。补充自验还曾发现一行 80 字符的格式问题，已修正为不超过 79 字符，并重新完成全部检查。
- AGENTS.md 和技能步骤可以按工单顺序执行；`send` 将使用本报告推进到 `impl_done`，交付状态以脚本写入的 STATUS 和远端分支为准。
