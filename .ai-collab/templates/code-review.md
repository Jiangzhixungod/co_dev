---
ticket: {{TICKET}}
type: code-review
from: {{FROM}}
date: {{DATE}}
reviewed_head: {{CODE_HEAD}}
tool: /code-review          # 全程仅此一轮（COLLABORATION.md §4.3）
verdict: <pass | fail>
---

# 代码审查 {{TICKET}}

审查范围：`origin/main...{{CODE_HEAD}}`（不含 `.ai-collab/tickets/`）

## 1. 结论

<pass / fail，一两句话说明。必改项几条，Claude 自己核对了什么>

## 2. 发现清单与处置

> `/code-review` 的结果必须逐条分诊，不能原样转发（协约 §4.3；规则见 `.claude/skills/collab-review/SKILL.md`）。
> 处置：**必改 F*n***（确认真实，并且违反契约或有实际影响）/ **可选**（真实但实际不影响）/ **不采纳**（误判、违背平台惯例、超出工单范围、风格偏好）。

| # | 严重度 | 文件:行 | 问题 | 处置 | 理由（必改项写清楚"什么输入、什么环境下出什么错"） |
|---|---|---|---|---|---|
| 1 | blocker / major / minor / note | | | 必改 F1 / 可选 / 不采纳 | |

## 3. 必改项（有则本消息即修复工单）

> 每条可独立验证。Codex 在 fix-report 里逐条对应编号回应。

- **F1** <要改什么> —— 验证：<怎么证明改好了>

## 4. 可选改进（不阻塞）

- 

## 5. 契约澄清（工单写得不严的地方，以此为准）

- 

## 6. 建议补充的测试

- 
