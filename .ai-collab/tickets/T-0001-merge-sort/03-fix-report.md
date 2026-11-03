---
ticket: T-0001-merge-sort
type: fix-report
from: codex
date: 2026-11-03T21:59:10+08:00
---

# 修复报告 T-0001-merge-sort

> 规则：COLLABORATION.md §4.4。**逐条**对应必改项编号；不同意的条目走质询，不要跳过。

| 编号 | 怎么修的 | 提交 | 怎么验证的（命令 + 结果摘录） |
|---|---|---|---|
| F1 | 从 sys.stdin.buffer 读取原始字节，固定按 UTF-8 解码；使用 backslashreplace 将非法字节保留为转义文本，使其所在词进入既有 int 转换失败路径。stdout 为空，stderr 单行错误，退出码 2，不受控制台输入编码影响。 | `4fb47ff` | 默认环境及 gbk:strict 下均实跑指定管道，非法 0x81 的错误输出逐字节一致，退出码均为 2；UTF-8 全角数字输出 1 2 3，退出码 0；20 组编码子进程检查、A1–A7、1200 组随机对照和百万元素检查全部通过。详见下方原始输出。 |

变更范围只有 `sortkit/__main__.py`，未改排序核心、受保护文件或既有消息。

## 验证命令与真实结果

环境：Windows cmd，`python --version` 为 `Python 3.11.9`。带引号的原始命令仍通过本机忽略目录中的 `.cmd` 执行。以下命令和输出从本机真实记录摘录；完整本机记录位于 `.ai-collab/runs/T-0001-merge-sort/`，不随 Git 交付。

### 1. 修复前复现

默认环境已返回错误码 2，但环境切换为 GBK 严格解码后复现 Claude 指出的 traceback 和退出码 1：

```text
> set PYTHONIOENCODING=gbk:strict
> python -c "import sys; sys.stdout.buffer.write(b'3 \x81 2\n')" | python -m sortkit
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "E:\a_work\co_dev\sortkit\__main__.py", line 30, in <module>
    sys.exit(main())
             ^^^^^^
  File "E:\a_work\co_dev\sortkit\__main__.py", line 17, in main
    for token in sys.stdin.read().split():
                 ^^^^^^^^^^^^^^^^
UnicodeDecodeError: 'gbk' codec can't decode byte 0x81 in position 2: illegal multibyte sequence
> echo %ERRORLEVEL%
1
```

### 2. 修复后：默认环境

```text
> python -c "import sys; sys.stdout.buffer.write(b'3 \x81 2\n')" | python -m sortkit > .ai-collab\runs\T-0001-merge-sort\F1-default.stdout.txt 2> .ai-collab\runs\T-0001-merge-sort\F1-default.stderr.txt
> echo %ERRORLEVEL%
2
> type .ai-collab\runs\T-0001-merge-sort\F1-default.stderr.txt
error: invalid integer: \x81
> for %F in (.ai-collab\runs\T-0001-merge-sort\F1-default.stdout.txt) do @echo stdout_size=%~zF
stdout_size=0
> python -c "import sys; sys.stdout.buffer.write('1 \uff13 2\n'.encode('utf-8'))" | python -m sortkit
1 2 3
> echo %ERRORLEVEL%
0
```

这里 `\uff13` 即全角 `３`，与审查指定的 UTF-8 输入字节相同，避免 cmd 批处理文件自身编码干扰用例。

### 3. 修复后：GBK 严格环境

```text
> set PYTHONIOENCODING=gbk:strict
> python -c "import sys; sys.stdout.buffer.write(b'3 \x81 2\n')" | python -m sortkit > .ai-collab\runs\T-0001-merge-sort\F1-gbk.stdout.txt 2> .ai-collab\runs\T-0001-merge-sort\F1-gbk.stderr.txt
> echo %ERRORLEVEL%
2
> type .ai-collab\runs\T-0001-merge-sort\F1-gbk.stderr.txt
error: invalid integer: \x81
> for %F in (.ai-collab\runs\T-0001-merge-sort\F1-gbk.stdout.txt) do @echo stdout_size=%~zF
stdout_size=0
> python -c "import sys; sys.stdout.buffer.write('1 \uff13 2\n'.encode('utf-8'))" | python -m sortkit
1 2 3
> echo %ERRORLEVEL%
0
```

这两种环境的非法 0x81 用例均没有 traceback；另以真实 CLI 子进程精确断言 stdout、stderr 和退出码。额外输入包括嵌入词中的非法字节、多种损坏的 UTF-8 序列、emoji / 中文非法词，以及合法的全角数字、阿拉伯数字、Unicode 空白、`+5`、`-0`、`1_000`。命令和真实输出：

```text
> set PYTHONIOENCODING=utf-8&& python .ai-collab/tmp/T-0001-F1-checks.py > .ai-collab/runs/T-0001-merge-sort/F1-extra.txt 2>&1
> type .ai-collab\runs\T-0001-merge-sort\F1-extra.txt
默认环境：7 组非法输入和 3 组 UTF-8 合法输入全部通过
gbk:strict：7 组非法输入和 3 组 UTF-8 合法输入全部通过
0x81 的默认环境和 gbk:strict 错误输出逐字节一致
cmd 管道的原始 stdout/stderr 文件与退出码证据一致
F1 全部 20 组子进程自验通过
```

临时检查脚本退出码 0，未新增正式测试套件。

### 4. A1–A7 复测

```text
> python --version
Python 3.11.9
> python -m compileall -q sortkit
> python -c "from sortkit import merge_sort; print(merge_sort([3, 1, 2]))"
[1, 2, 3]
> python -c "from sortkit import merge_sort; print(merge_sort([(1, 'b'), (0, 'x'), (1, 'a')], key=lambda t: t[0]))"
[(0, 'x'), (1, 'b'), (1, 'a')]
> python -c "from sortkit import merge_sort; print(merge_sort([(1, 'b'), (0, 'x'), (1, 'a')], key=lambda t: t[0], reverse=True))"
[(1, 'b'), (1, 'a'), (0, 'x')]
> python -c "from sortkit import merge_sort; a = [3, 1, 2]; merge_sort(a); print(a)"
[3, 1, 2]
> echo 3 -1 2 | python -m sortkit
-1 2 3
> echo 3 -1 2 | python -m sortkit -r
3 2 -1
> echo 3 x 2 | python -m sortkit > .ai-collab\runs\T-0001-merge-sort\A6.stdout.txt 2> .ai-collab\runs\T-0001-merge-sort\A6.stderr.txt
> echo %ERRORLEVEL%
2
> type .ai-collab\runs\T-0001-merge-sort\A6.stderr.txt
error: invalid integer: x
> for %F in (.ai-collab\runs\T-0001-merge-sort\A6.stdout.txt) do @echo stdout_size=%~zF
stdout_size=0
> findstr /L /N "sorted( .sort( heapq bisect" sortkit\*.py
> echo %ERRORLEVEL%
1
```

compileall 无输出，退出码 0；findstr 无匹配输出，退出码 1 表示没有禁用 API 文本，符合 A7。

### 5. 随机对照、边界和百万元素复测

按审查要求将固定种子 0 的随机对照扩大到 1200 组（长度为 0、1、2、3、7、16、31、64、100、257，每种长度 60 份带重复 key 的输入，分别验证升降序结果和稳定性）。同时重跑此前的边界检查和百万元素逆序输入；命令退出码 0：

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
固定种子随机对照：1200 组通过（包含升降序重复键稳定性）
命令行：8 组精确 stdout/stderr/退出码检查通过
A6 文件内容及 A7 禁用 API 文本检查：通过
Python 3.8 语法解析及行长检查：通过（实际运行环境为 Python 3.11.9）
百万元素逆序输入：完整排序、输入不变、无 RecursionError；耗时 2.826 秒
全部临时自验通过
> git diff --check
> python -m compileall -q sortkit
```

最后两条命令均无错误输出，退出码 0。百万级输入逐项核对完整输出，耗时仅是本次实测，不作为性能门限。

## 顺手处理的可选项

- 无。本轮仅处理必改项 F1 及审查并入其中的输入编码一致性问题；未扩展到整数位数上限、BrokenPipeError 或排序性能优化。

## 新增或变化的风险

- 输入编码按最新审查澄清固定为 UTF-8，不再依赖控制台代码页；实际 GBK 编码的非 ASCII 输入若不是有效 UTF-8，会按非法词处理，这是本次明确约定的行为。
- 非法 UTF-8 字节以 `\xNN` 形式出现在错误词中，符合审查允许的转义表示；在默认环境和 GBK 严格环境下已验证输出一致。
- 仍只在 Python 3.11.9 上实际运行；Python 3.8 只做兼容语法检查。正式三层测试仍等待 Claude 的测试方案，当前不宣称已完成验收。
