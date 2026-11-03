# 交接入口

**新会话从这里开始。**

- Claude：任务书 `docs/handover/next-session-prompt.md` 由 SessionStart hook 自动载入；hook 没生效时，第一条消息只需要一句：
  **「读 docs/handover/next-session-prompt.md，按它执行」**
- Codex：`AGENTS.md` 自动载入；开场跑 `scripts\collab.cmd inbox -As codex`。
- ⚠️ **任务书只承载"下一轮那一条线"。** 项目全景在 §1，接手时先扫一眼，否则会把"当前任务做完"误当成"项目做完"。

## 1. 项目全景（**只做导航，不写状态**）

> ⚠️ 本节刻意不写"做到哪了"。写了就会烂：同一件事写两处、只维护一处，另一处必然漂移，
> 而漂的那份恰好在新会话最先读、最信任的位置。**状态一律去每条线自己的权威来源看。**

| 线 | 范围 | 状态看哪里 | 阻塞性质 |
|---|---|---|---|
| A. 协作基建 | 协约、脚本、钩子、技能、交接体系 | [tracker §A](../plan/tracker.md) | 工作量 |
| B. 需求与架构 | 项目领域、技术栈、构建测试契约、设计文档 | [project-profile](../design/project-profile.md)、[tracker §B](../plan/tracker.md) | 等用户给出项目内容 |
| C. 实施（工单流） | 一张张工单：派单 → 编码 → 审查 → 测试 → 验收 → 合并 | `scripts\collab.cmd inbox`（工单状态的唯一真源） | 等 B |

**总账（所有待办的唯一清单）**：[tracker](../plan/tracker.md)。
**任何摘要与它冲突，以它为准；发现摘要错了，改摘要，不要改总账。**
**工单状态以各工单的 `STATUS` 为准**，用 `collab inbox` 现取。

## 2. 接手要读的（按顺序）

1. 本文（尤其 §1 的全景）
2. [`next-session-prompt.md`](next-session-prompt.md)：本轮做什么
3. 交接件 [`co_dev-handover.md`](co_dev-handover.md)：**读它最后一个 `## 0x` 节**
   （`grep -n '^## 0' docs/handover/co_dev-handover.md | tail -1` 就是它）。
   ⚠️ **不要在这里写死节号**，写死了就会落后而没人发现。往前**倒着读，以后写的为准**。
4. [tracker](../plan/tracker.md) 的相关节
5. 合作协约 [`COLLABORATION.md`](../../COLLABORATION.md)

## 3. 工作流循环

```
用户提需求 → Claude 设计、拆单、派单 → Codex 编码 → Claude /code-review（一轮）
  → Codex 修复 → Claude 主 agent 复审 → Claude 出测试方案（三层 + harness 边界）
  → Codex 测试、出报告 → Claude 审报告、验收 → 用户确认 → 合入 main
```

**收口时必做的四件**（少一件，下一轮就会踩空）：

1. **重写**任务书的任务段（覆盖，不追加），**重画那棵树**
2. 在交接件**追加**一个新状态节，写清**哪些既有结论被本轮订正了**
3. 在 **tracker** 勾选、更新对应条目
4. **不要**把状态复制进本文 §1，那是漂移的唯一来源

## 4. 门禁基线与命令

构建与测试命令见 [project-profile](../design/project-profile.md) 的"构建与测试契约"。协作命令见协约 §12。

## 5. 方法论出处

[可移植的会话交接工作流](../workflow/portable-session-handover.md)：每条规则旁边都记着它对应的那次真实事故。
