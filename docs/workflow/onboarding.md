# 两台机器接入指南（一次性）

| | 用户本机（Claude 侧） | 同事电脑（Codex 侧） |
|---|---|---|
| 系统 | Windows | Windows（Codex 在 cmd 下运行） |
| AI | Claude Code | Codex CLI |
| 远端地址 | `git@github-co_dev:Jiangzhixungod/co_dev.git`（部署密钥 + 别名） | `git@github.com:Jiangzhixungod/co_dev.git`（本人账号密钥） |

前提：两台机器都装了 Git for Windows（自带 Git Bash 和 OpenSSH）。

---

## 用户本机（已完成，留档）

1. 生成密钥 `ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\id_ed25519_github`
2. `~/.ssh/config` 加别名（**不占用 `github.com`**，不影响其他项目的 johnhowl 账号）：
   ```
   Host github-co_dev
       HostName github.com
       User git
       IdentityFile ~/.ssh/id_ed25519_github
       IdentitiesOnly yes
   ```
3. 公钥加到仓库 Settings → Deploy keys，勾选 **Allow write access**
4. 验证：`ssh -T git@github-co_dev`，看到 `Hi Jiangzhixungod/co_dev!` 即成功

---

## 同事电脑（Codex 侧），在 cmd 里操作

### 1. 访问权限：用 gh 自助完成（同事就是仓库所有者 Jiangzhixungod）

```bat
winget install --id GitHub.cli -e
gh auth login
```

按提示依次选择：**GitHub.com → SSH → 生成新的 SSH 密钥**（已有密钥就选上传已有的）**→ 用浏览器登录**。
`gh` 会把公钥上传到 Jiangzhixungod 账号。验证：`ssh -T git@github.com`，看到 `Hi Jiangzhixungod!` 即成功。

> 另一种做法：只想给这台机器开放这一个仓库的权限时，可以改用部署密钥（所有者才能添加）：
> `ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\id_ed25519_co_dev`，然后
> `gh repo deploy-key add %USERPROFILE%\.ssh\id_ed25519_co_dev.pub -R Jiangzhixungod/co_dev --allow-write --title "codex 侧"`，
> 再像用户本机那样在 `~/.ssh/config` 里配一个别名。

### 2. 克隆与初始化

```bat
cd /d D:\
gh repo clone Jiangzhixungod/co_dev
cd co_dev
git config user.name "<同事的名字>"
git config user.email "<同事的邮箱>"
scripts\collab.cmd setup
scripts\collab.cmd inbox -As codex
```

`setup` 会安装提交钩子（受保护路径护栏）并配置 `pull.ff=only`。

### 3. Codex 配置

- **联网**：Codex 要执行 `git fetch` / `git push`。如果沙箱禁止网络，在 `%USERPROFILE%\.codex\config.toml` 中允许工作区写入模式下的网络访问，或在 Codex 请求时手动批准这些命令。
- **信任项目**：在 `D:\co_dev` 下启动 Codex，信任这个目录，以便它载入 `AGENTS.md` 与 `.agents\skills\`。
- 验证：在 Codex 里问"你的开场步骤是什么"，它应该回答先跑 `scripts\collab.cmd inbox -As codex`；输入 `/skills`，应该能看到 `collab-worker` 和 `still-here`。

### 4. 日常

- 开 Codex 新会话：它会自动按 `AGENTS.md` 先查收件箱。也可以直接说"看看有没有轮到你的工单"。
- 有 ★ 工单：说"按 $collab-worker 处理 T-0001"。
- 下班或要换会话：说"收口"（`$still-here`）。
- 工单交出去后，可以在聊天里告诉用户一声"T-0001 编码完成了"；以仓库里的 STATUS 为准。

---

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `Permission denied (publickey)` | 密钥没加到仓库，或 `~/.ssh/config` 别名写错；用 `ssh -T git@github-co_dev` 排查 |
| cmd 里中文乱码 | `collab.cmd` 已切换到 UTF-8（chcp 65001）；如果直接运行 `collab.ps1` 出现乱码，改用 `collab.cmd` |
| `BLOCKED: 提交涉及受保护路径` | 你改了协作基建，按协约 §9 处理（Codex 应走质询） |
| `pull` 报 "Not possible to fast-forward" | 历史分叉了，违反了球权规则；停下来，在聊天里找用户一起看 |

---

## 附：local 模式（Claude 与 Codex 在同一台电脑、同一个仓库）

适用于一个人同时开 Claude Code 和 Codex 两个终端、在同一个目录里协作。规则与 remote 模式完全相同，只是不经过 GitHub。

```bat
cd /d <仓库目录>
scripts\collab.cmd setup -Mode local
```

- 送达：`send` 只提交，**提交即送达**；对方 `inbox` 立刻能看到。
- 工作区共享，所以**同一时间只进行一张工单**。球在对方手里时，不要改文件、不要切分支；脚本会拒绝会打断对方的切换。
- 两边的 `open` 都要带 `-As`（`-As claude` / `-As codex`）。
- 通知：在两个终端之间口头告诉对方"轮到你了"即可，以 `inbox` 为准。
- 仓库有 `origin` 远端时，`merge -Push` 会在合入本地 main 后同时推送 main；没有远端就只合入本地。
- 切回跨机器协作：`scripts\collab.cmd setup -Mode remote`。
