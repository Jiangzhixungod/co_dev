# co_dev 交接件

**追加式**：每轮收口追加一个 `## 0x` 状态节（0a、0b、0c……），节内可以就地订正。
新会话**只需要读最后一节**；需要更早的上下文时往前倒着读，**以后写的为准**。

找最后一节：`grep -n '^## 0' docs/handover/co_dev-handover.md | tail -1`

---

## 0a · 2026-11-03 · 协作基建落地

**本轮做了什么**

- 本机生成 GitHub 专用 SSH 密钥 `~/.ssh/id_ed25519_github`，作为**部署密钥（读写）**加到 `jiangzhixungod/co_dev`；
  `~/.ssh/config` 用别名 `github-co_dev`，**不占用** `github.com` 条目，不影响用户其他项目的 johnhowl 登录。
- 本机安装 gh CLI（v2.103.3），登录账号 Jiangzhixungod（只用于本仓库管理，例如添加部署密钥）。
- 从 AgentCollab_Template（`80eb526`）与 still-here（`e2c9a20`）迁移出协作体系，并做跨机器适配：
  协约 `COLLABORATION.md`、`CLAUDE.md`、`AGENTS.md`、`scripts/collab.ps1` 状态机、消息模板、commit-msg 钩子、
  Claude 技能（`.claude/skills/`）、Codex 技能（`.agents/skills/`）、SessionStart hook、交接文档。

**做了哪些决定（及理由）**

| 决定 | 理由 |
|---|---|
| Git 作为唯一通信渠道：一张工单 = 一条 `tkt/*` 分支 = 一个目录 | 双方在不同电脑；代码与消息同分支，审查范围天然清楚 |
| "球权"规则：只有持球方能推送工单分支 | 机械地杜绝双方同时改同一分支造成的冲突 |
| 产物格式从 JSON Schema 改为带 front matter 的 Markdown | 人类（用户、同事）也要读；字段逐一沿用原 schema |
| `/code-review` 每单仅一轮，之后由主 agent 复审，返工 ≤ 2 次 | 用户的流程要求；脚本计数强制 |
| 测试方案三层 + 每层 8 项 harness 边界声明 | 用户要求"必须有 harness 边界"；此处把它解释为测试夹具/环境的边界（SUT、替身、隔离、观测点等） |
| Codex 侧脚本：`collab.cmd` → Windows PowerShell 5.1 | 同事机器是 Windows cmd；5.1 是 Windows 自带 |
| hook 输出纯文本，不依赖 jq | SessionStart 的 stdout 本身就会进入上下文，少一个依赖 |

**被本轮订正的既有结论**

- （首轮，无）

**待确认**

- "harness 边界"的理解是否符合用户本意（见上表）。
- 项目领域、技术栈、构建测试契约：全部待用户提供。
