# 下一轮任务书（Claude）

> **新会话的开场只需要一句：「读 docs/handover/next-session-prompt.md，按它执行」**（hook 生效时连这句都不用说）。
>
> - 最近更新：2026-11-03 ｜ 对应交接件状态节：**0a**
> - **覆盖式，只保留下一轮那一份。** 收口时整段重写，不要追加。
> - **不写会漂移的数字**（工单状态、测试计数、未推送数），用 `scripts/collab.cmd inbox -As claude` 现取。

## 我在哪（每轮收口时重画这棵树）

```
co_dev
├─ A. 协作基建 ··············· 已搭好并推送到 GitHub（见交接件 0a）
│  └─ 同事机器接入 ⬅ 等同事按 onboarding 操作
├─ B. 需求与架构 ⬅ 当前这条线
│  └─ 项目参数 ⬅ 本轮做这个：向用户问清项目内容，填写 project-profile
└─ C. 实施（工单流）·········· 🔒 等 B（项目参数未填写前不派实施工单）
   └─ T-0001 试点工单：用一张小工单走通全流程
```

**本轮完成后往上走**：

| 回到 | 那一级还剩什么 |
|---|---|
| ↑ B. 需求与架构 | 架构设计文档（docs/design/）、首批工单拆分 |
| ↑↑ 根 | A 的同事接入；C 的全部实施 |

⚠️ 状态在树里画一次，**权威在 tracker 和各工单的 STATUS**；冲突时以它们为准。
树每轮**整体重画**，所以不会漂移；复制到别处的副本才会。

## 先读

1. `docs/handover/README.md`，**尤其 §1 的全景**
2. 交接件 `docs/handover/co_dev-handover.md` 的最后一个状态节
3. `docs/plan/tracker.md`
4. 跑 `scripts/collab.cmd inbox -As claude`

## 开工前有没有待拍板的事

有。**这个项目要做什么，用户还没说。** 协作骨架是通用的，项目参数全部空着。

# 任务：填写项目参数，准备试点工单

1. 向用户问清楚，并写进 `docs/design/project-profile.md`（受保护路径，提交带 `Override: 用户提供项目参数`）：
   - 项目领域与目标用户
   - 技术栈（语言、框架、运行环境；同事的 Windows 机器上是否已装好）
   - 构建命令；单元、集成、全量回归三层测试各自的运行命令和测试框架
   - 只读参考资料
2. 确认同事机器已按 `docs/workflow/onboarding.md` 接入：同事那边 `scripts\collab.cmd setup` 正常，Codex 能 push。
3. 设计并派发 **T-0001 试点工单**：选一个小而真实的切片（例如项目骨架 + 一个最小功能 + 三层测试各一个用例），目的是**把协作全流程走通一遍**。走完后复盘：协约或脚本哪里不顺，就提修订。

## 判据怎么写

- **每条断言都必须演示它能失败**：撤掉被它保护的那件事，确认变红，再改回来。
- **比较用的量先量"无信息基线"**，包括"这段代码整个不执行时，验收数字是多少"。

## 现成的东西

| 用途 | 位置 |
|---|---|
| 合作协约 | `COLLABORATION.md` |
| 协作命令 | `scripts/collab.cmd`（协约 §12） |
| 消息模板 | `.ai-collab/templates/` |
| Claude 技能 | `/collab-dispatch` `/collab-review` `/collab-testplan` `/collab-accept` `/collab-resolve` `/still-here` |
| Codex 技能 | `$collab-worker` `$still-here`（`.agents/skills/`） |
| 同事接入步骤 | `docs/workflow/onboarding.md` |

## 后面还有什么

见 tracker。

## 工作方式（长期约定，逐轮继承）

- 全部用中文；代码标识符、命令、文件名用英文。
- Claude 不写产品代码；设计、工单、审查、测试方案、验收由 Claude 负责。
- 推送或合并 main、打标签、修订协约，先问用户。
- 本机 PowerShell 的 `bash` 是 WSL。协作命令统一走 `scripts/collab.cmd`。
- 本仓库远端用 SSH 别名 `github-co_dev`；不要动 `~/.ssh/config` 里的 `github.com` 条目（用户其他项目用的是 johnhowl 账号）。

## 收口时怎么更新这个文件

1. 把"先读"到"工作方式"之间整段**重写**成下一轮的任务，不要追加。
2. **重画"我在哪"那棵树。**
3. 更新页首的"最近更新"和"对应交接件状态节"。
4. 检查没有会漂移的数字。
