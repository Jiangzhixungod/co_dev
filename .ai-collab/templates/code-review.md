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

<pass / fail，一两句话说明>

## 2. 发现清单

| 严重度 | 文件:行 | 问题 | 理由 / 失败场景 |
|---|---|---|---|
| blocker / major / minor / note | | | |

## 3. 必改项（有则本消息即修复工单）

> 每条可独立验证。Codex 在 fix-report 里逐条对应编号回应。

- **F1** <要改什么> —— 验证：<怎么证明改好了>
- **F2**

## 4. 可选改进（不阻塞）

- 

## 5. 建议补充的测试

- 
