---
name: collab-worker
description: co_dev 工单执行流程（Codex 侧）：查收件箱、进入工单、按工单编码、按审查修复、按测试方案执行三层测试、发起质询、写报告并 send 给 Claude。处理 T-xxxx 工单、同事说"看看有没有活""开始编码""修 bug""跑测试"时使用。
---

# 工单执行（Codex）

规则来源：`COLLABORATION.md`（必须遵守）。本技能只写操作步骤。所有命令都在 **cmd** 下运行。

## 0. 收件、进入工单

```bat
scripts\collab.cmd inbox -As codex
scripts\collab.cmd open -Ticket T-0001 -As codex
```

**按序号读完**工单目录 `.ai-collab\tickets\T-0001-xxx\` 下的全部消息。最新那条就是当前指令；有 `resolution` 时，以它的新指令为准。

先判断能不能直接开干。不清楚、有错、做不到、或有更好的方案 → 跳到 **5. 质询**。

## 1. `dispatched`：编码

1. 按 `00-ticket.md` 的任务 K1、K2… 依次实现，只改"范围 → 做"里的内容。
2. 每完成一个逻辑单元就原子提交：`git commit -m "[T-0001] <动词开头的一句话>"`
3. 按"自测要求"跑命令，**保存真实输出**。
4. `scripts\collab.cmd msg -Type impl-report -As codex`，逐项填写（输出贴摘录，不要转述）。
5. `scripts\collab.cmd send -To impl_done -As codex`

## 2. `fix_requested` / `rework_requested`：修复

1. 找到最新的 `code-review` / `re-review` / `report-review`，列出全部 F、R 编号。
2. 逐条修复，各自原子提交；每条都用它写明的"验证"方式自验。
3. 不同意某条 → 不要硬改，也不要跳过，走 **5. 质询**。
4. `msg -Type fix-report -As codex`，逐条对应编号填写（怎么修的、提交号、验证结果）。
5. `send -To fix_done -As codex`

## 3. `test_dispatched` / `test_rejected`：测试

1. 读最新的 `test-plan`（`test_rejected` 时还要读 `report-review` 列出的补测项 T…）。
2. **严格按每层的 harness 边界实现测试**：单元测试禁网络，只在边界上用替身，不 mock 被测对象内部。测试代码先原子提交。
3. 执行三层，完整日志写到 `docs\testing\<工单目录名>\`：
   - 单元 → 集成 → 全量回归（干净检出、从零构建，并取 main 基线比对）
   - 逐个做变异演示：破坏行为 → 确认红在指定断言上（核对失败信息）→ **恢复代码**（变异不能留在提交里）
4. 测出产品缺陷：**不要顺手修**，写进报告的"发现的缺陷"（A 级低级错误除外，见 4）。
5. 提交日志：`git add docs\testing\... && git commit -m "[T-0001] 测试日志"`
6. `msg -Type test-report -As codex`，**只报实测事实**；没跑的写"未执行"及原因。
7. `send -To test_done -As codex`

## 4. A 级自治修复（任何阶段）

确定性、局部、不改契约 / 接口 / 测试期望的低级错误，可以直接修：

```bat
scripts\collab.cmd fixnote -Summary "<摘要>" -Why "<为什么属于 A 级>"
git add <文件> FIXLOG.md
git commit -m "[autofix] <摘要>"
```

拿不准是不是 A 级，就当 B 级处理，走质询。

## 5. 质询

```bat
scripts\collab.cmd msg -Type query -As codex
rem 填写：指向哪条、类型、问题、你的立场、证据（报错 / 输出 / 矛盾原文）、建议方案
scripts\collab.cmd send -To query -As codex
```

质询发出后球就到了 Claude 那边，**等裁决，不要继续改这条分支**。

## send 失败时

| 提示 | 处理 |
|---|---|
| 工单目录外有未提交改动 | 先把代码 commit，再 send |
| 远端有本地没有的提交 | `scripts\collab.cmd open -Ticket ...` 同步后重试 |
| 现在球在 claude 手里 | 你不该动这张工单，去 inbox 看看别的 |
| 消息只追加不改写 | 你改了已发送的消息：`git checkout -- <文件>` 撤销，另发新消息 |
| push 失败 | 检查网络和 SSH（见 docs\workflow\onboarding.md） |

## 完成后

用一两句话告诉同事：工单号、做了什么、球现在交给了 Claude（同事可以顺便通知用户）。
