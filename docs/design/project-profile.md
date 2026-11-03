# 项目参数（Project Profile）

> **受保护路径**（协约 §9）：由 Claude 与用户确认后修改，提交带 `Override:` trailer；Codex 有异议时走质询。
> 协约 §11：**本文件填写之前，不派实施工单。**
>
> ⚠️ **当前为"协作流程真机试点"参数。** 正式项目内容确定后整份替换。

## 1. 项目领域

- 做什么：**sortkit**，一个稳定归并排序的小型 Python 库，加命令行入口。
- 为什么做：用一个小而真实的编程任务，在两台电脑之间把 派单 → 编码 → 审查 → 修复 → 测试 → 验收 → 合并 完整走通一遍。
- 成功标准：T-0001 合入 main；三层测试全部通过；协作流程中遇到的问题都记录下来，用于修订协约。

## 2. 技术栈

| 项 | 选择 | 同事机器（Windows）上是否就绪 |
|---|---|---|
| 语言 / 运行时 | Python ≥ 3.8 | 待 Codex 在 impl-report 中确认（`python --version`） |
| 框架 | 无 | — |
| 包管理 | 无（**只用标准库，不装任何第三方包**） | — |
| 测试框架 | 标准库 `unittest` | 随 Python 自带 |

如果同事机器上的命令是 `py -3` 而不是 `python`，以下命令照此替换，并在报告里注明。

## 3. 构建与测试契约

所有命令都在仓库根目录、Windows cmd 下运行。

| 用途 | 命令 | 必须全绿？ |
|---|---|---|
| 安装依赖 | 无 | — |
| 构建（语法检查） | `python -m compileall -q sortkit` | 是 |
| 单元测试 | `python -m unittest discover -s tests/unit -t . -v` | 是 |
| 集成测试 | `python -m unittest discover -s tests/integration -t . -v` | 是 |
| 全量回归 | `python -m unittest discover -s tests -t . -v` | 是 |
| 取 main 基线 | 在 `origin/main` 的干净检出上运行"全量回归"命令 | — |

测试目录约定：`tests/unit/`、`tests/integration/`，每个目录都要有 `__init__.py`。

已知的不稳定测试及判别方法：`无`

## 4. 只读参考资料

- Python 内置 `sorted()` 的语义（稳定排序、`key`、`reverse`）：作为行为对照的"预言"，**只允许在测试代码里使用**。

## 5. 修订记录

| 日期 | 内容 |
|---|---|
| 2026-11-03 | 建立空白骨架 |
| 2026-11-03 | 填入真机试点参数（sortkit，Python 标准库） |
