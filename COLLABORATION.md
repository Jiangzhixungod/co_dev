# co_dev 合作协约（Claude × Codex）

> **版本 v1.0 ｜ 生效 2026-11-03 ｜ 适用：本仓库全部工作**
>
> 本协约是 Claude 与 Codex **共同遵守的唯一权威规约**。`CLAUDE.md`、`AGENTS.md`、
> `.claude/skills/`、`scripts/` 都只是它的执行入口；任何入口与本协约冲突，**以本协约为准**，
> 并把那个入口当缺陷修掉。
>
> 来源：流程沿用 [AgentCollab_Template](https://github.com/johnhowl/AgentCollab_Template)
> （指挥-执行分工、对齐通道、分级自治、受保护路径），跨会话连续性沿用
> [still-here](https://github.com/johnhowl/still-here)。本版做了**跨机器适配**：
> Claude 与 Codex 在两台电脑上，**以 Git 仓库为唯一通信渠道**。

---

## 1. 参与方与职责

| 参与方 | 在哪 | 负责 | 不做 |
|---|---|---|---|
| **项目负责人**（用户） | 本机 | 定方向；拍板；确认合并与推送 `main`；裁决升级事项 | — |
| **Claude** | 用户本机，Claude Code | 架构、方案、实施计划；派单；代码审查；测试方案；测试报告审查与验收；Git 生命周期决策（分支、合并、标签） | 不写产品代码（用户明确授权除外）；不替 Codex 跑测试来充当证据 |
| **同事** | 同事电脑 | 操作 Codex；批准 Codex 侧需要人工确认的动作 | — |
| **Codex** | 同事电脑，Windows cmd | 按工单编码与自测；按审查意见修复；按测试方案实现并执行测试；出报告 | 不改协作基建（§9 受保护路径）；不改 Claude 写的消息；不自行扩大范围 |

**Codex 不是被动执行者。** 工单不清楚、技术上有错、被阻塞，或有证据支持更好的做法时，
**必须走质询通道（§7）**，不得静默偏离，也不得硬着头皮照做。

---

## 2. 通信：Git 就是消息总线

双方不在同一台电脑，**只通过** GitHub 仓库 `Jiangzhixungod/co_dev` 交换信息。

| 概念 | 规定 |
|---|---|
| **工单 = 分支 = 目录** | 分支 `tkt/T-0001-<slug>`，目录 `.ai-collab/tickets/T-0001-<slug>/`（slug 用小写英文、数字、连字符）。工单的全部消息与全部代码改动都在这条分支上；验收后合入 `main`，目录随之归档 |
| **消息文件** | 目录内按序号追加 `NN-<类型>.md`（`00-ticket.md`、`01-impl-report.md`…）。**只追加，不改写**：发出的消息不再修改，要更正就发一条新消息 |
| **STATUS** | 目录内的 `STATUS` 是该工单状态的**唯一真源**。纯 ASCII，**只由脚本写**，禁止手改 |
| **球权** | 每个状态有且只有一个持球方（§3）。**只有持球方可以向这条分支推送。** 这条规则保证双方永远不会同时改同一条分支 |
| **发信** | 持球方用 `collab send` 推进状态：脚本校验转移是否合法、提交、推送。**推送即送达** |
| **收信** | `collab inbox` 拉取远端并列出所有工单，标出轮到自己的（★） |
| **口头通知** | 人类在聊天里说一句"T-0001 编码完成了"可以加快节奏，但**以 STATUS 为准**，口头消息不算交付 |

命令入口（cmd、PowerShell、Git Bash 通用）：`scripts\collab.cmd <子命令>`，速查见 §12。

---

## 3. 工单生命周期

```
draft ─派单─▶ dispatched ─编码完成─▶ impl_done ─[/code-review，全程仅一轮]─┐
                                                                              │
     ┌────────────────────────── 有必改项 ◀──────────────────────────────────┤
     ▼                                                                        │ 无必改项
fix_requested ─修复完成─▶ fix_done ─[Claude 主 agent 复审]─┐                  │
     ▲                       ▲                              │ 通过             │
     │                       └── rework_requested ◀─有问题──┤（返工 ≤ 2 次）   │
     │                                                      ▼                 ▼
     │                                              review_passed ◀───────────┘
     │                                                      │ 出测试方案
     │                                                      ▼
     │                        test_rejected ──补测──▶ test_dispatched ─测试完成─▶ test_done
     │                              ▲                                              │
     │                              └──────── 证据不足 / 漏测 ◀─[审查测试报告]─────┤
     └──────────────────────────────────── 测出产品缺陷 ◀──────────────────────────┤
                                                                     通过 ▼
                                                     accepted ─用户确认─▶ merged

旁路：Codex 持球的任一状态 ─质询─▶ query ─Claude 裁决─▶ 回到 Codex 持球状态（或 blocked）
      任一未结束状态 ─▶ blocked（等人类拍板） ；Claude 可将任一未结束状态 ─▶ cancelled
```

| 状态 | 持球 | 含义 | 持球方要做什么 | 产出消息 |
|---|---|---|---|---|
| `draft` | claude | 工单起草中（尚未推送） | 写工单 | `ticket` |
| `dispatched` | codex | 实施工单已派发 | 编码、自测 | `impl-report` |
| `impl_done` | claude | 编码完成，待审查 | 跑 `/code-review`（仅此一轮） | `code-review` |
| `fix_requested` | codex | 修复单已派发 | 逐条修复 | `fix-report` |
| `fix_done` | claude | 修复完成，待复审 | 主 agent 复审 | `re-review` |
| `rework_requested` | codex | 复审仍有问题 | 返工 | `fix-report` |
| `review_passed` | claude | 审查通过 | 写测试方案 | `test-plan` |
| `test_dispatched` | codex | 测试单已派发 | 实现并执行测试 | `test-report` |
| `test_done` | claude | 测试报告已提交 | 审查报告 | `report-review` |
| `test_rejected` | codex | 报告被打回 | 补测、补证据 | `test-report` |
| `accepted` | claude | 验收通过 | 请用户确认后合并 | （合并提交） |
| `query` | claude | Codex 质询中 | 裁决 | `resolution` |
| `blocked` | 人类 | 等人类拍板 | 人类决定后由 Claude 推进 | `note` |
| `merged` / `cancelled` | — | 已结束 | — | — |

**合法转移**（`collab send` 强制校验，非法转移直接拒绝）：

| 从 | 到 | 由谁 |
|---|---|---|
| `draft` | `dispatched` | claude |
| `dispatched` | `impl_done` | codex |
| `impl_done` | `fix_requested` / `review_passed` / `test_dispatched` | claude |
| `impl_done` | `accepted` | claude（**仅限**调研、文档类不含代码的工单） |
| `fix_requested`、`rework_requested` | `fix_done` | codex |
| `fix_done` | `rework_requested` / `review_passed` / `test_dispatched` | claude |
| `review_passed` | `test_dispatched` | claude |
| `test_dispatched`、`test_rejected` | `test_done` | codex |
| `test_done` | `test_rejected` / `fix_requested` / `accepted` | claude |
| `accepted` | `merged` | claude（通过 `collab merge`） |
| Codex 持球的任一状态 | `query` | codex |
| `query` | Codex 持球的任一状态、`blocked` | claude |
| 任一未结束状态 | `blocked` | 当前持球方，或 claude |
| `blocked` | 任一未结束状态 | claude（依据人类决定） |
| 任一未结束状态 | `cancelled` | claude |

---

## 4. 各阶段规范

### 4.1 派单（Claude → Codex，`00-ticket.md`）

必须包含：目标；背景与约束；范围（做什么 / **不做什么**）；任务分解（每项：编号、说明、目标路径、依赖、自验方式）；接口与契约变更；**可判定的**验收标准（命令 + 期望结果，不写"功能正常"）；自测要求；风险与待确认事项；参考资料。

质量线：**Codex 不追问就能开工。** 一张工单的规模控制在一次审查能看完（经验值：代码 diff 约 800 行以内），大需求拆成多张。项目参数（§11）未填写前，只派调研或设计类工单。

### 4.2 编码完成报告（Codex → Claude，`impl-report`）

- 代码先以**原子提交**提交到工单分支（`[T-0001] <动词开头的一句话>`），再写报告、`send`。
- 报告逐项对应任务编号：完成情况、变更文件、关键设计决定、自测命令与**真实输出摘录**、与工单的偏差及原因、遗留风险。
- `send` 会把当前 HEAD 记为 `code_head`，审查以它为准。

### 4.3 代码审查：`/code-review` 一轮（Claude，`code-review`）

- 每张工单**只跑一次** `/code-review`，对象是 `origin/main...code_head` 的代码 diff（不含 `.ai-collab/tickets/`）。默认档位 `high`，用户可改。
- 结果写入消息：结论（`pass` / `fail`）；发现清单（严重度 `blocker` / `major` / `minor` / `note`，文件:行，问题，理由）；**必改项**编号 `F1`、`F2`…（每条可独立验证）；建议补充的测试。
- 有必改项 → `fix_requested`（**这份审查就是修复工单**）；无必改项 → `review_passed`，或直接接着出测试方案转 `test_dispatched`。
- `minor` / `note` 不阻塞，Codex 可顺手修，不强制。

### 4.4 修复报告（Codex → Claude，`fix-report`）

逐条对应 `F` / `R` 编号：怎么修的、提交号、怎么验证的。**不同意某条**：不要硬改，也不要跳过，走质询（§7）。

### 4.5 主 agent 复审（Claude，`re-review`）

- **不再跑 `/code-review`。** Claude 主 agent 亲自审 `reviewed_head..code_head`（上次审查之后的改动）：每个必改项是否**真正**关闭，修复是否引入新问题。
- 仍有问题 → `rework_requested`，只列未关闭项与新问题（新问题编号 `R1`、`R2`…）。
- 返工**最多 2 次**（脚本计数）；第 3 次仍不过 → `blocked`，交人类决定（拆单、改方案或换思路）。

### 4.6 测试方案（Claude → Codex，`test-plan`）

**三层都要有**，每层都要有 **harness 边界声明**：

| 层 | 被测对象（SUT） | 边界外依赖 | 硬性要求 |
|---|---|---|---|
| **单元测试** | 单个函数 / 类 / 模块 | 全部用替身（mock / stub / fake）；时钟、随机数、环境变量通过注入控制 | 不访问网络，不依赖真实外部服务；单用例快速完成 |
| **集成测试** | 多个模块协作，或模块 + 真实基础设施（文件系统、数据库、子进程等） | 只替换**系统之外**的第三方服务 | 环境可一键重建；用例之间没有共享的可变状态 |
| **全量回归** | 仓库全部既有测试 + 本单新增测试 | 与项目测试契约一致 | 干净检出、从零构建；与 `main` 基线比对，**任何新增失败即不通过** |

**harness 边界声明**（每层逐项填写，缺项即方案不合格）：

1. **SUT 边界**：哪些模块真实运行。
2. **替身清单**：每个替身替换了什么、放在哪条边界上。**只能在边界上替换，不得 mock 被测对象内部。**
3. **输入与夹具**：数据从哪来、怎么生成、随机种子。
4. **环境与隔离**：临时目录、端口、数据库实例、并发方式；单元测试禁止访问网络。
5. **观测点**：断言观察什么（返回值、输出文件、状态、日志）。
6. **资源与超时**：单用例超时、整层超时。
7. **不在本层验证的内容**：逐项列出，并指明由哪一层负责。
8. **通过判据**：可判定的条件。**不得用重试掩盖不稳定**：不稳定用例单独列出并说明原因。

**两条证据纪律**（来自 still-here，与领域无关，必须遵守）：

- **先量无信息基线。** 每个验收数字都要写明"被测代码完全不执行时它等于多少"，并确认门限在正确一侧。能被"函数直接返回 false / 空 / 0"满足的验收数字是**无效判据**。
- **新断言必须演示能失败。** 本单新增的关键断言，方案里要指定一个变异：**破坏被测行为**（不是篡改断言的输入），确认测试变红、并且**红在指定的那条断言上**（匹配失败信息，不只看退出码），然后恢复。

用例表：编号（`U-1` / `I-1` / `R-1`）、层、描述、夹具、命令、期望、判据。

### 4.7 测试报告（Codex → Claude，`test-report`）

环境（操作系统、工具链版本、被测提交号）；每层的执行命令；**原始输出摘录**（完整日志放 `docs/testing/<工单号>/` 并给出路径）；通过 / 失败 / 跳过计数；逐用例结果；变异演示结果；发现的缺陷（含复现步骤）；偏离测试方案之处及原因。

**只报实测事实。** 没跑的写"未执行"及原因，**不得推测结果**。

### 4.8 报告审查与验收（Claude，`report-review`）

逐条核对：命令是否按方案执行、计数是否自洽、证据能否支撑结论、无信息基线与变异演示是否到位。

- 证据不足或漏测 → `test_rejected`，列出补测项。
- 测出产品缺陷 → `fix_requested`，缺陷即修复项；修复后走主 agent 复审，再回到测试（重跑全量回归）。
- 全部满足 → `accepted`：写明结论、验证摘要、遗留风险、后续建议。

### 4.9 合并

`accepted` 之后，Claude **先请用户确认**，再执行 `collab merge -Push`：工单分支以 `--no-ff` 合入 `main`、推送、删除远端工单分支。版本标签（SemVer `vX.Y.Z`）由 Claude 在里程碑时提出，用户确认后再打。

---

## 5. 跨会话连续性（still-here 适配）

AI 会话不记得上一轮。长期项目会同时出现三种问题：**失忆**（重复劳动、推翻已验证的结论）、**文档漂移**（同一状态写在多处，只维护一处）、**只见树木**（把"当前任务做完"当成"项目做完"）。

**Claude 侧**（用户本机）

| 文件 | 写什么 | 可变性 |
|---|---|---|
| `docs/handover/next-session-prompt.md` | 下一轮任务书，开头是"我在哪"的树 | **覆盖式**：每轮整体重写 |
| `docs/handover/co_dev-handover.md` | 每轮一个 `## 0x` 状态节，写清**哪些既有结论被本轮订正** | **追加式** |
| `docs/plan/tracker.md` | 所有待办的唯一清单（总账），冲突以它为准 | 活文档 |
| `docs/handover/README.md` | 入口页：全景导航 | **只写指针，不写状态** |

SessionStart hook（`.claude/settings.json`）在开场时自动注入任务书与收件箱快照。任务书过期（之后有新提交，或工作区有未提交改动）时，hook 会给出警告。`CLAUDE.md` 是 hook 失效时的兜底。

**Codex 侧**（同事电脑）

- `AGENTS.md` 由 Codex 自动载入，其中规定开场第一件事是 `scripts\collab.cmd inbox -As codex`。
- 工单目录本身就是完整上下文：按序号读消息即可。
- 会话中途结束时写 `WIP-codex.md`（工单目录内，**覆盖式**：做到哪、下一步、未决问题），并用 `collab wip -As codex -Commit` 提交、推送。`inbox` 会检查它之后是否还有新提交或未提交改动，有就提示过期。发出下一条正式消息时，脚本会自动删除它。

**技能入口**（两边各一套，内容都指向本协约，不另立规则）：

| | Claude（Claude Code） | Codex（Codex CLI） |
|---|---|---|
| 常驻契约（自动载入） | `CLAUDE.md`（导入本协约） | `AGENTS.md` |
| 技能目录 | `.claude/skills/` | `.agents/skills/` |
| 调用方式 | `/collab-dispatch` `/collab-review` `/collab-testplan` `/collab-accept` `/collab-resolve` `/still-here` | `$collab-worker` `$still-here`，或 `/skills` 选择；任务匹配时自动选用 |
| 开场自动化 | SessionStart hook | `AGENTS.md` 规定开场先跑 `inbox` |

**收口触发词**（双方通用，意思对即可，不必逐字）：「收口」「交接」「按交接工作流收口」「wrap up」。

- **Claude 收到**：① 重写任务书、重画树；② 交接件追加状态节，写明本轮订正了什么；③ 更新总账；④ **不要**把状态写进入口页。
- **Codex 收到**：提交当前代码（可以是 WIP 提交）；覆盖写 `WIP-codex.md`；推送工单分支。

**摘要只留指针，不留值。** 测试计数、未推送数、工单状态这类会变的东西，一律用命令现取（`collab inbox`、`collab diff`），不写进文档。

---

## 6. 改动分级与自治边界

| 级别 | 定义 | Codex 怎么做 |
|---|---|---|
| **A 级** | 确定性、范围局部、**不改任何契约 / 接口 / 测试期望**的低级缺陷（拼写、漏掉的 import、明显的空值判断等） | 直接修；`collab fixnote` 记入 `FIXLOG.md`；单独提交，提交信息以 `[autofix]` 开头 |
| **B 级** | 改工单、审查、测试方案的要求；改接口或数据结构；改测试期望或容差；动协作基建（§9）；跨工单范围；**任何拿不准的情况** | 必须走质询（§7） |

---

## 7. 质询与对齐通道

- Codex 在**自己持球的任何状态**都可以发起质询：`collab msg -Type query` 写消息，`collab send -To query`。脚本会记住质询前的状态。
- 每条质询包含：编号；指向（哪份消息的哪一项）；类型（`clarification` 澄清 / `disagreement` 异议 / `blocker` 阻塞 / `proposal` 提议）；问题；Codex 的立场；**证据**（报错、命令输出、互相矛盾的原文）；建议方案。
- Claude **按证据而不按身份**裁决，写 `resolution`，每条一个决定：
  - `accept_codex`：Codex 对，给出新的权威指令；
  - `revise`：双方都要调整，给出新的权威指令；
  - `reject`：维持原指令，说明理由；
  - `defer`：需要人类决定。
- 裁决后 `collab send` 回到 Codex 持球的状态；含 `defer` 的转 `blocked`。
- 同一问题往返 **2 轮**仍不收敛 → `blocked`，双方立场一并交人类。

---

## 8. Git 规范

| 项 | 规定 |
|---|---|
| 主干 | `main` 只接收验收通过的合并；**推送 `main` 必须先经用户确认** |
| 工单分支 | `tkt/T-NNNN-<slug>`，从最新的 `origin/main` 创建 |
| 提交信息 | `[T-0001] <动词开头的一句话>`；A 级修复用 `[autofix] ...` |
| 拉取 | 只用快进（`collab setup` 已配置 `pull.ff=only`）；**禁止改写已推送的历史** |
| 强推 | 禁止对任何共享分支 `push --force` |
| 推送工单分支 | 持球方在 `collab send` 时自动推送，无需另行确认（这就是投递消息） |
| 跟上 main | 工单分支落后 `main` 且影响审查或测试时，由 Claude 在消息中要求，Codex 执行 `git merge origin/main` |
| 版本标签 | SemVer，Claude 提出，用户确认 |
| 身份 | 每台机器在本仓库内配置自己的 `user.name` / `user.email`，不改全局配置 |

---

## 9. 受保护路径

以下路径是"规则引擎"，改动属于 B 级。提交信息必须带下列 trailer 之一，否则 `commit-msg` 钩子拒绝提交：

```
COLLABORATION.md   CLAUDE.md   AGENTS.md   .gitignore   .gitattributes
.ai-collab/templates/   .ai-collab/README.md   scripts/   .claude/   .agents/
docs/workflow/   docs/design/project-profile.md
```

```
Aligned-By: T-0001/05-resolution.md     基于一次对齐裁决
Override: <理由>                         用户明确授权
```

合并提交不受此限（被合并的提交已经各自过检）。工单消息目录 `.ai-collab/tickets/` 不在保护范围内。

**协作工具自身的回归门禁**：改动 `scripts/`、`.claude/hooks/` 之后，必须先在 Git Bash 里跑通
`bash scripts/tests/collab-e2e.sh`（全部 PASS），再提交。这个测试在本机模拟两台机器，把状态机完整走一遍。

---

## 10. 必须停下来等人类的情形

推送或合并 `main`；打版本标签；`blocked` 状态；修订本协约；`defer` 裁决；返工超过 2 次；对齐 2 轮不收敛；涉及密钥、账号、付费资源；任何不可逆或对外的操作。

---

## 11. 项目参数

项目领域、技术栈、构建与测试契约、只读参考资料，统一写在 `docs/design/project-profile.md`（受保护路径）。
**项目参数未填写前，不派实施工单。**

---

## 12. 命令速查

所有命令都是 `scripts\collab.cmd <子命令> [参数]`。在 Git Bash 里写作 `scripts/collab.cmd`。

| 子命令 | 谁用 | 作用 |
|---|---|---|
| `setup` | 双方，每台机器一次 | 安装 git 钩子、配置 `pull.ff=only` 等，并检查身份与远端 |
| `inbox -As <claude\|codex>` | 双方，**每次开场** | 拉取远端，列出所有工单，★ 标出轮到自己的；检查 WIP 是否过期 |
| `new -Slug <slug>` | claude | 从 `origin/main` 建工单分支与目录，生成 `00-ticket.md` |
| `open -Ticket T-0001` | 双方 | 切到工单分支并快进到远端最新，显示状态与消息列表 |
| `msg -Ticket T-0001 -Type <类型> -As <角色>` | 双方 | 按模板生成下一条序号消息 |
| `send -Ticket T-0001 -To <状态> -As <角色>` | 持球方 | 校验转移 → 写 STATUS → 提交 → 推送 |
| `diff -Ticket T-0001 [-Since reviewed]` | claude | 显示待审代码 diff 的统计和完整查看命令 |
| `wip -Ticket T-0001 -As <角色> [-Commit]` | 持球方 | 生成或提交覆盖式 WIP 存档 |
| `merge -Ticket T-0001 [-Push]` | claude | 已验收工单 `--no-ff` 合入 `main`；`-Push` 需要用户事先确认 |
| `fixnote -Summary ... -Why ...` | codex | A 级修复记入 `FIXLOG.md` |

消息类型：`ticket`、`impl-report`、`code-review`、`fix-report`、`re-review`、`test-plan`、`test-report`、`report-review`、`query`、`resolution`、`note`。

---

## 13. 修订

修订本协约：Claude 起草 → 用户确认 → 提交时带 `Override:` trailer → 版本号加 0.1 → 在下表记录。
Codex 认为协约有问题，走质询通道提出。

| 版本 | 日期 | 内容 |
|---|---|---|
| v1.0 | 2026-11-03 | 初版：AgentCollab_Template + still-here 的跨机器适配 |
