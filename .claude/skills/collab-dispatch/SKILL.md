---
name: collab-dispatch
description: 把需求拆成工单并派发给 Codex（建工单分支、写 00-ticket.md、send -To dispatched）。用户提出新功能/新需求、要求"派单""给 Codex 派活""拆任务"时使用。
---

# 派单（协约 §4.1）

前置：`docs/design/project-profile.md` 已填写项目参数；未填写时只能派调研或设计类工单（`kind: research | docs`）。

1. **先想清楚再拆单。** 需要架构决定时，先在 `docs/design/` 写设计文档，跟用户确认。一张工单要能在一次审查中看完（代码 diff 约 800 行以内）；大需求拆成多张，并写清依赖顺序。
2. 建工单：
   ```
   scripts/collab.cmd new -Slug <小写英文短名>
   ```
   脚本会从 `origin/main` 切出 `tkt/T-NNNN-<slug>`，并生成 `00-ticket.md` 与 `STATUS(draft)`。
3. 填写 `00-ticket.md` 的全部 9 节。自查：
   - Codex **不追问就能开工**吗？目标路径、接口、约束都写明了吗？
   - "不做"写了吗？
   - 每条验收标准都是"命令 + 期望结果"吗？都写了**无信息基线**吗？能被"函数直接返回空 / false"满足的判据要改掉。
4. 派发：
   ```
   scripts/collab.cmd send -To dispatched -As claude
   ```
5. 在 `docs/plan/tracker.md` 加上这张工单（只写指针：工单号、标题、依赖；**状态以 STATUS 为准，不抄状态**）。tracker 在 `main` 上改：先 `git switch main`，收口时一起提交。
6. 告诉用户：工单号、一句话目标、需要同事让 Codex 跑 `scripts\collab.cmd inbox -As codex`。
