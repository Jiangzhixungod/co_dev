---
name: collab-testplan
description: 为审查通过的工单写三层测试方案（单元 / 集成 / 全量回归，每层都有 harness 边界声明，含无信息基线与变异演示），并派发给 Codex。review_passed 时，或复审通过后要转测试时使用。
---

# 测试方案（协约 §4.6）

1. `scripts/collab.cmd open -Ticket T-NNNN -As claude`；重读 `00-ticket.md` 的验收标准，以及审查里的"建议补充的测试"。
2. `scripts/collab.cmd msg -Type test-plan -As claude`，逐节填写：
   - **0 构建与环境**：命令取自 `docs/design/project-profile.md` 的构建与测试契约。
   - **1-3 三层**：每层的 harness 边界 **8 项逐项填写**，缺一项方案就不合格。
     - 单元测试：SUT 是单个模块；边界外全部用替身；时钟、随机数、环境变量通过注入控制；**禁网络**。
     - 集成测试：只替换系统之外的第三方服务；环境可一键重建；用例之间没有共享的可变状态。
     - 全量回归：干净检出、从零构建；与 main 基线比对，**任何新增失败即不通过**。
     - "不在本层验证"一项必须指明由哪一层负责，三层合起来不能留空洞。
   - **4 证据纪律**：
     - 每个验收数字都写出无信息基线，并确认门限在基线的正确一侧。
     - 每条新增的关键断言配一个变异：**破坏行为**（不是篡改断言的输入），写清应被哪条断言接住、期望的失败信息。
   - **5 不稳定用例**：不得用重试掩盖。
3. 自查：Codex 能照着方案直接跑吗？每条判据都可判定吗？
4. `scripts/collab.cmd send -To test_dispatched -As claude`
