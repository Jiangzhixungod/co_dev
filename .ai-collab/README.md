# .ai-collab — 协作基础设施

Claude 与 Codex 的跨机器协作目录。规则见根目录 `COLLABORATION.md`，本文只说明目录结构和来源。

| 路径 | 内容 | 谁写 |
|---|---|---|
| `templates/` | 各阶段的消息模板（`collab msg` / `collab new` 使用） | 受保护，改动走协约修订 |
| `tickets/T-NNNN-<slug>/` | 一张工单的全部往来：`NN-<类型>.md` 消息、`STATUS`、可能有 `WIP-<角色>.md` | 持球方（经 `collab send`） |

进行中的工单在各自的 `tkt/*` 分支上；`main` 上的 `tickets/` 只保存**已合并**工单的归档。
查看进行中的工单用 `scripts\collab.cmd inbox`，不要在 `main` 上翻目录。

## 来源与适配

| 上游 | 版本 | 沿用 | 改动 |
|---|---|---|---|
| [AgentCollab_Template](https://github.com/johnhowl/AgentCollab_Template) | `80eb526` | 角色分工（Claude 指挥、Codex 执行）；对齐通道（query → resolution，accept_codex / revise / reject / defer，2 轮不收敛升级人类）；A/B 级自治 + FIXLOG；受保护路径 + `Aligned-By` / `Override` trailer 钩子；Git 生命周期由 Claude 决定、push main 需人类确认 | **传输层**：原模板用 `claude -p` 在同一台机器上编排，现改为 Git 工单分支 + 状态机脚本（双方在不同电脑）。**格式**：JSON Schema 产物改为带 front matter 的 Markdown 消息模板（字段逐一沿用：task-plan → `ticket`，review → `code-review` / `re-review`，test-spec → `test-plan`，summary → `report-review`，query / resolution 同名，git-directive → `collab merge`）。**审查回合**：原 `MaxReviewRounds=3` 改为 `/code-review` 一轮 + 主 agent 复审 ≤2 次返工。**测试**：test-spec 增加三层与 harness 边界声明。去掉 `post-commit` 自动打标签 |
| [still-here](https://github.com/johnhowl/still-here) | `e2c9a20` | 任务书（覆盖式，含"我在哪"树）/ 交接件（追加式）/ 总账 / 入口页只写指针；收口四件事与触发词；SessionStart 注入 + 过期警告；两条证据纪律（无信息基线、新断言须演示能失败）；方法论原文 → `docs/workflow/portable-session-handover.md` | hook 改为输出纯文本（不再依赖 jq），附带协作收件箱快照；过期检查以 `main` 为准。**Codex 侧**：`AGENTS.md` 规定开场先跑 `inbox`；工单内覆盖式 `WIP-codex.md`，由 `inbox` 做过期检查；技能 `$still-here` |
