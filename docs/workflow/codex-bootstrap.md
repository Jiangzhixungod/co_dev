# Codex 一次性接入引导

**用途**：在同事的电脑上，让 Codex 自己完成"装 gh → 部署密钥 → SSH 别名 → 克隆 → 初始化"。
克隆完成后，`AGENTS.md` 会自动接管；之后的 pull 由 `scripts\collab.cmd` 在每次 `inbox` / `open` / `send` 时自动完成。

**用法**：在 cmd 里进入任意目录（例如 `D:\`）启动 Codex，把下面整段粘贴给它。

**唯一需要本人做的一步**：`gh auth login` 的浏览器授权（GitHub 要求人工确认）。
Codex 写 `~/.ssh`、安装软件、联网时会请求批准，逐个批准即可。

---

````text
你要在这台 Windows 电脑上为 co_dev 项目做一次性接入。仓库是 Jiangzhixungod/co_dev（私有），我就是 Jiangzhixungod 本人。
按顺序执行；每一步先检查是否已完成，已完成就跳过。命令以 cmd 写法给出，如果你在 PowerShell 里执行，换成等价写法
（例如 %USERPROFILE% 写作 $env:USERPROFILE；ssh-keygen 的空密码在 PowerShell 5.1 里要写成 -N '""'）。

1. 工具：运行 git --version 和 gh --version。
   缺少 gh 时运行：winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
   装好后如果当前终端找不到 gh，就用完整路径 "C:\Program Files\GitHub CLI\gh.exe"。

2. GitHub 登录：运行 gh auth status。
   如果没有登录 Jiangzhixungod，不要自己运行登录命令。请告诉我："请在终端运行 gh auth login，选 GitHub.com → SSH → 跳过上传密钥 → 浏览器登录"，
   等我说"好了"后，再用 gh auth status 确认登录的是 Jiangzhixungod。

3. 部署密钥（只授权 co_dev 这一个仓库，最小权限）：
   a. 如果 %USERPROFILE%\.ssh\id_ed25519_co_dev 不存在：
      ssh-keygen -t ed25519 -N "" -C "co_dev-codex" -f %USERPROFILE%\.ssh\id_ed25519_co_dev
   b. 运行 gh repo deploy-key list -R Jiangzhixungod/co_dev。如果里面没有这把公钥（对比 .pub 文件的内容）：
      gh repo deploy-key add %USERPROFILE%\.ssh\id_ed25519_co_dev.pub -R Jiangzhixungod/co_dev --allow-write --title "codex 侧 %COMPUTERNAME%"
   c. 如果 %USERPROFILE%\.ssh\config 里还没有 "Host github-co_dev"，在文件末尾追加下面 5 行（文件不存在就新建；不要改动已有内容）：
         Host github-co_dev
             HostName github.com
             User git
             IdentityFile ~/.ssh/id_ed25519_co_dev
             IdentitiesOnly yes
   d. 验证：ssh -T -o StrictHostKeyChecking=accept-new git@github-co_dev
      输出包含 "Hi Jiangzhixungod/co_dev!" 才算成功（这条命令的退出码是 1，属于正常）。

4. 克隆：如果 D:\co_dev 不存在，在 D:\ 下运行 git clone git@github-co_dev:Jiangzhixungod/co_dev.git；
   如果已经存在，进入该目录运行 git pull --ff-only。

5. 初始化：cd /d D:\co_dev
   问我提交时用的名字和邮箱，然后运行 git config user.name "<名字>" 和 git config user.email "<邮箱>"（只写入本仓库，不要用 --global）。
   再运行 scripts\collab.cmd setup -Mode remote。

6. 完成后：完整阅读 D:\co_dev\AGENTS.md 和 D:\co_dev\COLLABORATION.md，运行 scripts\collab.cmd inbox -As codex，把结果告诉我。
   之后请在 D:\co_dev 目录重新启动 Codex，让它自动载入 AGENTS.md 和 .agents\skills。

7. 可选：问我是否要运行 gh auth logout。登出后，这台机器对 GitHub 的访问只剩这把部署密钥，也就只能访问 co_dev。

全程禁止：上传或打印私钥（只使用 .pub）；修改 ~/.ssh/config 里已有的条目；git push --force；修改仓库中 AGENTS.md 列出的受保护文件。
````

---

## 接入之后

- **以后的 pull**：不需要手动执行。`collab inbox` / `open` / `send` 都会先拉取远端；`AGENTS.md` 要求 Codex 每次开场先跑 `inbox`。
- **日常**：在 `D:\co_dev` 启动 Codex，说"按 $collab-worker 处理收件箱里的工单"。
- **（以后可选）无人值守**：可以用 Windows 计划任务定时运行 `codex exec`，让它自动查收件箱、接单。这样做意味着 agent 在无人看着的情况下改代码、推送，建议先人工跑通几轮，再考虑开启。
