---
ticket: {{TICKET}}
type: re-review
from: {{FROM}}
date: {{DATE}}
range: {{REVIEWED_HEAD}}..{{CODE_HEAD}}
tool: claude-main-agent     # 不再跑 /code-review（COLLABORATION.md §4.5）
verdict: <pass | rework>
---

# 主 agent 复审 {{TICKET}}

审查范围：上次审查之后的改动 `{{REVIEWED_HEAD}}..{{CODE_HEAD}}`

## 1. 必改项核对

| 编号 | 是否关闭 | 依据（看了哪段代码 / 跑了什么） |
|---|---|---|
| F1 | 关闭 / 未关闭 | |

## 2. 修复引入的新问题

- **R1** <问题> —— 验证：<怎么证明改好了>

## 3. 结论

<pass → 转测试；rework → 列出仍需处理的编号（返工计数见 STATUS）>
