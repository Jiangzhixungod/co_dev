---
name: still-here
description: 会话交接收口（still-here 工作流）：重写任务书并重画"我在哪"的树、交接件追加状态节、更新总账。用户说"收口""交接""交接一下""按交接工作流收口""wrap up""我要新开对话"，或意思是这一轮到此为止时使用。
---

# 收口（协约 §5；方法论 docs/workflow/portable-session-handover.md）

先把手上的工单处理到一个干净点：该 send 的 send；工单分支上没有未提交的东西。然后：

```
git switch main
git pull --ff-only
scripts/collab.cmd inbox -As claude      # 现取工单状态，不凭记忆
```

**四件事，少一件下一轮就会踩空：**

1. **重写** `docs/handover/next-session-prompt.md`：从"先读"到"工作方式"整段覆盖，不要追加。
   - **重画"我在哪"那棵树**：当前位置，以及完成后回到哪一级、那一级还剩什么。
   - 更新页首的"最近更新"日期和"对应交接件状态节"。
   - **不写会漂移的数字**（工单状态、测试计数、未推送数）。写成"跑 `collab inbox` 现取"。
2. 在 `docs/handover/co_dev-handover.md` **追加**一个新的 `## 0x` 节（字母顺延）：本轮做了什么、做了哪些决定、**哪些既有结论被本轮订正了**。
3. 在 `docs/plan/tracker.md` 勾选、更新条目。
4. **不要**往 `docs/handover/README.md` 写状态。它只写指针。

收尾：

```
git add docs/handover docs/plan
git commit -m "docs: 收口 <日期> <一句话>"
```

**推送 main 前先问用户。** 用户确认后执行 `git push origin main`。
