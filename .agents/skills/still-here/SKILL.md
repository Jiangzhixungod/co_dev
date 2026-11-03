---
name: still-here
description: 跨会话连续性（Codex 侧）：新会话开场核对上次做到哪、WIP 存档是否过期；会话结束前收口，写覆盖式 WIP 存档并提交推送。新会话开始、同事说"收口""交接""wrap up""先到这里"、或工单没做完会话就要结束时使用。
---

# still-here（Codex 侧）

AI 会话不记得上一轮。Codex 侧的连续性靠三样东西：**收件箱**（工单状态的唯一真源）、**工单目录**（完整的消息记录）、**WIP 存档**（覆盖式，记录中途做到哪）。

## 开场

```bat
git status
scripts\collab.cmd inbox -As codex
```

- ★ 是轮到你的工单。`open` 进入后，按序号读完消息。
- inbox 显示"有 WIP 存档"：先读 `WIP-codex.md`，从"下一步"接着做。
- inbox 显示"WIP 存档可能已过期"（存档之后又有提交，或有未提交改动）：**不要盲信存档**。先看 `git log --oneline -10`、`git status`、`git diff`，弄清实际做到了哪里，再继续；需要时先重写存档。

## 收口（同事说「收口」「交接」「wrap up」「先到这里」，或会话即将结束而工单未完成）

1. 能正式交付的，就直接按 `$collab-worker` 写报告并 send。发出正式消息后，WIP 存档会被自动删除，不用再收口。
2. 不能交付，就存档：
   ```bat
   scripts\collab.cmd wip -As codex
   ```
   **整份重写** `WIP-codex.md`：正在处理哪条消息、做到哪、下一步（编号步骤）、未决问题、别踩的坑。不要追加旧内容。
3. 提交并推送（会把当前全部改动作为 WIP 提交）：
   ```bat
   scripts\collab.cmd wip -As codex -Commit
   ```
4. 告诉同事：工单号、做到哪、下次会话从哪里接着做。

## 不要做的事

- 不要把工单状态、测试计数这类会变的数字抄进存档；下次用 `inbox` 现取。
- 球不在你手里时不要 `wip -Commit`（脚本会拒绝）。
