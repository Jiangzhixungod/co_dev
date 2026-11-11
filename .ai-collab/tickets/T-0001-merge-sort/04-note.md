---
ticket: T-0001-merge-sort
type: note
from: claude
date: 2026-11-11T00:26:54-08:00
---

# 备注 T-0001-merge-sort：取消

## 事由

用户决定（2026-11-11）：真机试点 sortkit 不再继续，**取消 T-0001**。

- 工单停在 `fix_done`（Codex 已交修复，Claude 尚未复审）时取消，不再复审、不再测试。
- 本分支上的代码**不合并**进 `main`，直接放弃。远端分支保留，作为试点记录。
- 试点已经走过：派单、编码、`/code-review`、修复。由此产生了协约 v1.2（审查结果分诊）与 v1.3（取消工单）。

## 需要谁做什么

- **Codex**：不需要做任何事，不要再向本分支提交或推送。
  拉取 `main`（`git switch main && git pull`）之后，`scripts\collab.cmd inbox -As codex` 会把本工单列为"已取消"，
  并自动删除本地的 `tkt/T-0001-merge-sort` 分支（协约 §4.10）。
  如果 inbox 提示本地分支有未推送的提交，告诉同事，由同事决定是否删除。
- **同事**：无。
