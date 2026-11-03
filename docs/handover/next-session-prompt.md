# 下一轮任务书（Claude）

> **新会话的开场只需要一句：「读 docs/handover/next-session-prompt.md，按它执行」**（hook 生效时连这句都不用说）。
>
> - 最近更新：2026-11-03 ｜ 对应交接件状态节：**0a**
> - **覆盖式，只保留下一轮那一份。** 收口时整段重写，不要追加。
> - **不写会漂移的数字**（工单状态、测试计数、未推送数），用 `scripts/collab.cmd inbox -As claude` 现取。

## 我在哪（每轮收口时重画这棵树）

```
co_dev
├─ A. 协作基建 ··············· 已推送 GitHub；e2e 回归全绿
│  └─ 同事机器接入 ··········· 等同事操作（onboarding）
├─ B. 真机试点 sortkit ⬅ 当前这条线
│  └─ T-0001 稳定归并排序 + CLI ⬅ 已派单，跟进它走完全流程
│     ├─ 派单 ✅
│     ├─ 编码 → /code-review（一轮）→ 修复 → 主 agent 复审
│     ├─ 测试方案（Claude）→ 测试程序 + 执行（Codex）→ 报告审查
│     └─ 验收 → 用户确认 → 合并 → 复盘
├─ C. 正式项目 ··············· 🔒 等用户给出项目内容
└─ D. 流程通用化 ············· 🔒 等 B 复盘
```

**本轮完成后往上走**：

| 回到 | 那一级还剩什么 |
|---|---|
| ↑ B. 真机试点 | 复盘：收集流程问题，修订协约 / 脚本（改脚本必须跑 e2e） |
| ↑↑ 根 | C 正式项目；D 通用化（模板仓库 + 一键安装） |

⚠️ 状态在树里画一次，**权威在 tracker 和各工单的 STATUS**；冲突时以它们为准。

## 先读

1. `docs/handover/README.md`，**尤其 §1 的全景**
2. 交接件 `docs/handover/co_dev-handover.md` 的最后一个状态节
3. `docs/plan/tracker.md`
4. 跑 `scripts/collab.cmd inbox -As claude`

## 开工前有没有待拍板的事

无。（"harness 边界"的理解见交接件 0a，若用户另有所指，按用户的意思修订协约 §4.6。）

# 任务：跟进 T-0001，把真机试点走到闭环

按 inbox 上 T-0001 的状态行动（协约 §3 的状态表）：

| 状态 | 动作 |
|---|---|
| `dispatched` | 等 Codex。可以问用户：同事是否已接入？ |
| `impl_done` | `/collab-review`：跑**唯一一轮** `/code-review`。重点核对 reverse 稳定性（先升序再整体反转的写法是错的）、key 只计算一次、不修改入参、不使用内置排序 |
| `fix_done` | `/collab-review`：主 agent 复审（**不再跑 /code-review**） |
| `review_passed` | `/collab-testplan`：Claude 写方案，Codex 写测试程序。用 `sorted()` 做对照预言（只许出现在测试代码里），随机用例固定种子；变异至少覆盖：reverse 不稳定、修改入参、CLI 错误退出码 |
| `test_done` | `/collab-accept`：审查报告 |
| `accepted` | 预览合并 → **请用户确认** → `merge -Push` |
| `query` | `/collab-resolve` |

闭环之后：和用户、同事一起复盘，把流程问题记进交接件，并提出协约修订。

## 判据怎么写

- **每条断言都必须演示它能失败**：撤掉被它保护的那件事，确认变红，再改回来。
- **比较用的量先量"无信息基线"**，包括"这段代码整个不执行时，验收数字是多少"。

## 现成的东西

| 用途 | 位置 |
|---|---|
| 合作协约 | `COLLABORATION.md` |
| 协作命令 | `scripts/collab.cmd`（协约 §12） |
| 协作工具的回归测试 | `bash scripts/tests/collab-e2e.sh` |
| 消息模板 | `.ai-collab/templates/` |
| Claude 技能 | `/collab-dispatch` `/collab-review` `/collab-testplan` `/collab-accept` `/collab-resolve` `/still-here` |
| Codex 技能 | `$collab-worker` `$still-here`（`.agents/skills/`） |
| 同事接入步骤 | `docs/workflow/onboarding.md` |

## 后面还有什么

见 tracker 的 C、D 两条线。

## 工作方式（长期约定，逐轮继承）

- 全部用中文；代码标识符、命令、文件名用英文。
- Claude 不写产品代码，测试程序也由 Codex 写；设计、工单、审查、测试方案、验收由 Claude 负责。
- 推送或合并 main、打标签、修订协约，先问用户。
- 本机 PowerShell 的 `bash` 是 WSL。协作命令统一走 `scripts/collab.cmd`。
- 本仓库远端用 SSH 别名 `github-co_dev`；不要动 `~/.ssh/config` 里的 `github.com` 条目（用户其他项目用的是 johnhowl 账号）。
- 身份边界：本仓库内作者 Jiangzhixun、只操作 Jiangzhixungod/co_dev；本仓库外作者 johnhowl。本机 gh 未登录（详见 CLAUDE.md "本机执行注意"）。

## 收口时怎么更新这个文件

1. 把"先读"到"工作方式"之间整段**重写**成下一轮的任务，不要追加。
2. **重画"我在哪"那棵树。**
3. 更新页首的"最近更新"和"对应交接件状态节"。
4. 检查没有会漂移的数字。
