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

| 测试分工：Claude 写测试方案，Codex 写测试程序 | 用户让 Claude 决定。理由：定标准与写实现分离；方案写死用例与对照预言；变异演示防止"自测自过" |
| 先做真机试点（sortkit，Python 标准库），正式项目内容后定 | 用户要求先用简单编程任务验证跨机器全流程 |
| 写入端到端回归测试 `scripts/tests/collab-e2e.sh`，并纳入协约 §9 门禁 | 模拟时发现的缺陷需要可重复的回归手段 |

**端到端模拟中发现并修复的缺陷**（均已有回归用例）

- inbox 停在落后的本地工单分支上时读了旧 STATUS，误报"0 张"→ 改为以远端为准
- open 先解析工单号后拉取 → 对方刚派的单打不开 → 改为先拉取
- 已合并工单的本地残留分支被列成"未推送"→ 自动清理（草稿分支不受影响）
- Git Bash 把 `origin/tkt/x:path` 改写成 `origin\tkt\x;path` → hook 读不到 STATUS → 关闭 MSYS 参数转换
- 多张工单并发追加 FIXLOG.md，合并会冲突 → `merge=union`

**被本轮订正的既有结论**

- "已在本地模拟两台机器走通全流程"一句，最初写进 tracker 时其实还没有验证；现已由 e2e（107 项全 PASS）支撑。

**待确认**

- "harness 边界"的理解是否符合用户本意（见上表）。
- 正式项目的领域、技术栈、构建测试契约：待用户提供。
- 流程通用化（用户提出）：等试点复盘后再做，见 tracker D。
