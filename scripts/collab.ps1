<#
.SYNOPSIS
    co_dev 协作工具：Claude x Codex 跨机器工单总线。规则见 COLLABORATION.md。

.DESCRIPTION
    入口：scripts\collab.cmd <命令> [参数]；不带参数显示帮助。
    兼容 Windows PowerShell 5.1 与 PowerShell 7。
    本文件必须保存为 UTF-8 with BOM（5.1 读无 BOM 的中文脚本会乱码）。
#>
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",
    [string]$Ticket = "",
    [string]$To = "",
    [string]$As = "",
    [string]$Type = "",
    [string]$Slug = "",
    [string]$Since = "",
    [string]$Summary = "",
    [string]$Why = "",
    [string]$Files = "",
    [switch]$Offline,
    [switch]$NoPush,
    [switch]$Push,
    [switch]$Commit
)

$ErrorActionPreference = "Stop"
$Utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $Utf8 } catch { }
$OutputEncoding = $Utf8

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Remote = "origin"
$TicketsRel = ".ai-collab/tickets"
$TemplatesDir = Join-Path $Root ".ai-collab\templates"
$CodeExclude = ":(exclude).ai-collab/tickets"

# ---------------------------------------------------------------- 状态机（与 COLLABORATION.md §3 一致）
$Owner = @{
    "draft" = "claude"; "dispatched" = "codex"; "impl_done" = "claude"
    "fix_requested" = "codex"; "fix_done" = "claude"; "rework_requested" = "codex"
    "review_passed" = "claude"; "test_dispatched" = "codex"; "test_done" = "claude"
    "test_rejected" = "codex"; "accepted" = "claude"; "query" = "claude"
    "blocked" = "human"; "merged" = "none"; "cancelled" = "none"
}
$Flow = @{
    "draft"            = @("dispatched")
    "dispatched"       = @("impl_done")
    "impl_done"        = @("fix_requested", "review_passed", "test_dispatched", "accepted")
    "fix_requested"    = @("fix_done")
    "rework_requested" = @("fix_done")
    "fix_done"         = @("rework_requested", "review_passed", "test_dispatched")
    "review_passed"    = @("test_dispatched")
    "test_dispatched"  = @("test_done")
    "test_rejected"    = @("test_done")
    "test_done"        = @("test_rejected", "fix_requested", "accepted")
}
$Terminal = @("merged", "cancelled")
$MaxRework = 2
$MsgTypes = @("impl-report", "code-review", "fix-report", "re-review", "test-plan",
              "test-report", "report-review", "query", "resolution", "note")
$StatusKeys = @("ticket", "state", "owner", "by", "updated", "message",
                "base", "code_head", "reviewed_head", "resume", "rework")

# ---------------------------------------------------------------- 输出
function Fail([string]$msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }
function Ok([string]$msg)   { Write-Host "✓ $msg" -ForegroundColor Green }
function Warn([string]$msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Info([string]$msg) { Write-Host $msg }

# ---------------------------------------------------------------- git 封装
# 取 stdout（丢弃 stderr），返回字符串数组；失败时报错退出，-AllowFail 时返回空数组。
function Invoke-GitOut {
    param([string[]]$GitArgs, [switch]$AllowFail)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & git -C $Root @GitArgs 2>$null
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    if ($code -ne 0) {
        if ($AllowFail) { return @() }
        Fail ("git " + ($GitArgs -join " ") + " 失败（退出码 $code）")
    }
    $lines = @()
    foreach ($o in @($out)) { if ($null -ne $o) { $lines += [string]$o } }
    return $lines
}

function Get-GitLine {
    param([string[]]$GitArgs)
    $r = @(Invoke-GitOut -GitArgs $GitArgs -AllowFail)
    if ($r.Count -gt 0) { return $r[0].Trim() }
    return ""
}

# 运行并把输出直接显示给用户；返回退出码，失败时报错退出（-AllowFail 除外）。
function Invoke-GitRun {
    param([string[]]$GitArgs, [switch]$AllowFail)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git -C $Root @GitArgs | Out-Host
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    if ($code -ne 0 -and -not $AllowFail) {
        Fail ("git " + ($GitArgs -join " ") + " 失败（退出码 $code）")
    }
    return $code
}

function New-Commit([string]$subject, [string[]]$trailers) {
    $tmp = [System.IO.Path]::GetTempFileName()
    $text = $subject + "`n`n" + ($trailers -join "`n") + "`n"
    [System.IO.File]::WriteAllText($tmp, $text, $Utf8)
    try { [void](Invoke-GitRun -GitArgs @("commit", "-q", "-F", $tmp)) }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Invoke-Fetch {
    if ($Offline) { return }
    $code = Invoke-GitRun -GitArgs @("fetch", "--prune", "--quiet", $Remote) -AllowFail
    if ($code -ne 0) { Warn "拉取远端失败（离线？），以下基于本地快照。" }
}

function Get-CurrentBranch { return (Get-GitLine @("symbolic-ref", "--short", "-q", "HEAD")) }

function Test-RefExists([string]$ref) {
    return ((Get-GitLine @("rev-parse", "--verify", "-q", $ref)) -ne "")
}

function Get-DirtyPaths([string]$excludeDirRel) {
    $paths = @()
    foreach ($l in @(Invoke-GitOut @("status", "--porcelain", "--untracked-files=all"))) {
        if ($l.Length -lt 4) { continue }
        $p = $l.Substring(3).Trim('"')
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1].Trim('"') }
        if ($excludeDirRel -and ($p -eq $excludeDirRel -or $p.StartsWith("$excludeDirRel/"))) { continue }
        $paths += $p
    }
    return $paths
}

function Assert-Clean([string]$why) {
    $d = @(Get-DirtyPaths "")
    if ($d.Count -gt 0) {
        $list = ($d | Select-Object -First 10) -join "`n  "
        Fail ("工作区有 {0} 处未提交改动，{1}。先提交（或 git stash）再继续：`n  {2}" -f $d.Count, $why, $list)
    }
}

# ---------------------------------------------------------------- 工单
function Get-Now { return (Get-Date).ToString("yyyy-MM-dd'T'HH:mm:sszzz") }

function Read-StatusText([string]$text) {
    $h = [ordered]@{}
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\s*([a-z_]+)\s*:\s*(.*?)\s*$') { $h[$Matches[1]] = $Matches[2] }
    }
    return $h
}

function Write-StatusFile([string]$path, $h) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($k in $StatusKeys) {
        if ($h.Contains($k)) { [void]$sb.Append($k + ": " + [string]$h[$k] + "`n") }
    }
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $Utf8)
}

function Get-AllTicketDirs {
    $set = @{}
    foreach ($r in @(Invoke-GitOut @("for-each-ref", "--format=%(refname:short)", "refs/remotes/$Remote/tkt/") -AllowFail)) {
        $set[$r.Substring(("$Remote/tkt/").Length)] = $true
    }
    foreach ($r in @(Invoke-GitOut @("for-each-ref", "--format=%(refname:short)", "refs/heads/tkt/") -AllowFail)) {
        $set[$r.Substring(4)] = $true
    }
    return @($set.Keys | Sort-Object)
}

function Resolve-Ticket([string]$t) {
    if ($t -eq "") {
        $cur = Get-CurrentBranch
        if ($cur.StartsWith("tkt/")) { return $cur.Substring(4) }
        Fail "请用 -Ticket 指定工单（如 -Ticket T-0001），或先 collab open 切到工单分支。"
    }
    if ($t -match '^\d+$') { $t = "T-{0:D4}" -f [int]$t }
    elseif ($t -match '^[tT]-(\d+)(.*)$') { $t = ("T-{0:D4}" -f [int]$Matches[1]) + $Matches[2] }
    $hits = @(Get-AllTicketDirs | Where-Object { $_ -eq $t -or $_.StartsWith("$t-") })
    if ($hits.Count -eq 1) { return $hits[0] }
    if ($hits.Count -eq 0) { Fail "找不到工单 $t（先 collab inbox 拉取一下？）" }
    Fail ("工单号 $t 有歧义：" + ($hits -join ", "))
}

function Get-TicketStatus([string]$dir) {
    $rel = "$TicketsRel/$dir/STATUS"
    $cur = Get-CurrentBranch
    if ($cur -eq "tkt/$dir") {
        $abs = Join-Path $Root $rel
        if (Test-Path -LiteralPath $abs) {
            return (Read-StatusText ([System.IO.File]::ReadAllText($abs, $Utf8)))
        }
    }
    foreach ($ref in @("$Remote/tkt/$dir", "tkt/$dir")) {
        $txt = @(Invoke-GitOut @("show", ($ref + ":" + $rel)) -AllowFail)
        if ($txt.Count -gt 0) { return (Read-StatusText ($txt -join "`n")) }
    }
    return [ordered]@{}
}

function Assert-Role {
    if ($As -ne "claude" -and $As -ne "codex") { Fail "请用 -As claude 或 -As codex 说明你是谁。" }
}

function Assert-OnTicketBranch([string]$dir) {
    $cur = Get-CurrentBranch
    if ($cur -ne "tkt/$dir") { Fail "当前在分支 '$cur'，不在 tkt/$dir。先运行：scripts\collab.cmd open -Ticket $dir" }
}

function Expand-Template([string]$name, [string]$dest, $vars) {
    $src = Join-Path $TemplatesDir "$name.md"
    if (-not (Test-Path -LiteralPath $src)) { Fail "模板不存在：$src" }
    $text = [System.IO.File]::ReadAllText($src, $Utf8)
    foreach ($k in $vars.Keys) { $text = $text.Replace("{{" + $k + "}}", [string]$vars[$k]) }
    [System.IO.File]::WriteAllText($dest, $text, $Utf8)
}

function Get-Messages([string]$dirAbs) {
    if (-not (Test-Path -LiteralPath $dirAbs)) { return @() }
    return @(Get-ChildItem -LiteralPath $dirAbs -File |
             Where-Object { $_.Name -match '^\d{2}-[a-z-]+\.md$' } |
             Sort-Object Name | ForEach-Object { $_.Name })
}

function Short([string]$sha) { if ($sha.Length -ge 8) { return $sha.Substring(0, 8) } return $sha }

function Show-Ticket([string]$dir) {
    $st = Get-TicketStatus $dir
    $dirAbs = Join-Path $Root "$TicketsRel/$dir"
    Info ""
    Info "工单 $dir   分支 tkt/$dir"
    Info ("  状态 {0}   持球 {1}   上次由 {2} 于 {3}" -f $st["state"], $st["owner"], $st["by"], $st["updated"])
    if ($st["code_head"]) { Info ("  code_head {0}   reviewed_head {1}   返工 {2}/{3}" -f (Short $st["code_head"]), (Short $st["reviewed_head"]), $st["rework"], $MaxRework) }
    if ($st["state"] -eq "query") { Info ("  质询前状态 {0}" -f $st["resume"]) }
    Info "  消息："
    foreach ($m in (Get-Messages $dirAbs)) { Info "    $TicketsRel/$dir/$m" }
    foreach ($w in @("WIP-claude.md", "WIP-codex.md")) {
        if (Test-Path -LiteralPath (Join-Path $dirAbs $w)) { Info "    $TicketsRel/$dir/$w   (WIP 存档)" }
    }
}

function Test-Transition([string]$from, [string]$to, [string]$role) {
    if (-not $Owner.ContainsKey($to)) { Fail ("未知状态 '$to'。可用：" + (($Owner.Keys | Sort-Object) -join ", ")) }
    if ($Terminal -contains $from) { Fail "工单已结束（$from），不能再发送。" }
    if ($to -eq "merged") { Fail "merged 只能通过 collab merge 完成。" }
    if ($to -eq "draft") { Fail "不能退回 draft。" }
    if ($to -eq "cancelled") {
        if ($role -ne "claude") { Fail "只有 claude 能取消工单。" }
        return
    }
    if ($to -eq "blocked") {
        if ($role -ne "claude" -and $Owner[$from] -ne $role) { Fail "现在球在 $($Owner[$from])，$role 不能把工单转 blocked。" }
        return
    }
    if ($from -eq "blocked") {
        if ($role -ne "claude") { Fail "blocked 只能由 claude 依据人类决定推进。" }
        return
    }
    if ($to -eq "query") {
        if ($role -ne "codex" -or $Owner[$from] -ne "codex") { Fail "只有 Codex 能在自己持球时发起质询（当前状态 $from）。" }
        return
    }
    if ($from -eq "query") {
        if ($role -ne "claude") { Fail "质询由 claude 裁决。" }
        if ($Owner[$to] -ne "codex") { Fail "裁决后只能回到 Codex 持球的状态或 blocked，不能到 $to。" }
        return
    }
    if ($Owner[$from] -ne $role) { Fail "现在球在 $($Owner[$from]) 手里（状态 $from），$role 不能发送。" }
    if (-not ($Flow.ContainsKey($from) -and ($Flow[$from] -contains $to))) {
        $legal = "无"
        if ($Flow.ContainsKey($from)) { $legal = $Flow[$from] -join ", " }
        Fail "非法转移：$from → $to。从 $from 可去：$legal（另可 blocked / cancelled）。"
    }
}

# ---------------------------------------------------------------- 命令
function Cmd-Help {
    Info @"
co_dev 协作工具    用法：scripts\collab.cmd <命令> [参数]      规则：COLLABORATION.md

  setup                                   每台机器一次：装钩子、pull.ff=only，检查身份与远端
  inbox  [-As claude|codex] [-Offline]    拉取远端并列出所有工单，★ = 轮到你（每次开场先跑）
  new    -Slug <英文短名>                 [claude] 从 origin/main 建工单分支和 00-ticket.md
  open   -Ticket T-0001                   切到工单分支并快进到远端最新，显示状态与消息
  msg    -Type <类型> -As <角色>          按模板生成下一条序号消息
  send   -To <状态> -As <角色> [-NoPush]  校验转移 → 写 STATUS → 提交 → 推送（持球方）
  diff   [-Since reviewed]                [claude] 待审代码 diff 统计与查看命令
  wip    -As <角色> [-Commit]             覆盖式 WIP 存档；-Commit 提交并推送当前全部改动
  merge  -Ticket T-0001 [-Push]           [claude] 不带 -Push 为预览；-Push 需用户事先确认
  fixnote -Summary <摘要> -Why <理由>     [codex] A 级自治修复记入 FIXLOG.md

  在工单分支上时，-Ticket 可省略（取当前分支）。
  消息类型：$($MsgTypes -join ", ")
  状态：draft dispatched impl_done fix_requested fix_done rework_requested review_passed
        test_dispatched test_done test_rejected accepted query blocked merged cancelled
"@
}

function Cmd-Setup {
    [void](Invoke-GitRun @("config", "core.hooksPath", "scripts/git-hooks"))
    [void](Invoke-GitRun @("config", "pull.ff", "only"))
    [void](Invoke-GitRun @("config", "core.quotepath", "false"))
    [void](Invoke-GitRun @("config", "push.autoSetupRemote", "true"))
    Ok "已配置：core.hooksPath=scripts/git-hooks  pull.ff=only  core.quotepath=false"
    $name = Get-GitLine @("config", "user.name")
    $mail = Get-GitLine @("config", "user.email")
    if ($name -eq "" -or $mail -eq "") {
        Warn "本仓库还没有提交身份。请设置（只写入本仓库）："
        Info '  git config user.name "<你的名字>"'
        Info '  git config user.email "<你的邮箱>"'
    } else { Ok "提交身份：$name <$mail>" }
    $url = Get-GitLine @("remote", "get-url", $Remote)
    if ($url -eq "") { Warn "没有远端 $Remote。请：git remote add origin <仓库地址>" } else { Ok "远端 ${Remote}：$url" }
}

function Cmd-Inbox {
    Invoke-Fetch
    $dirs = @(Get-AllTicketDirs)
    $cur = Get-CurrentBranch
    Info ""
    if ($dirs.Count -eq 0) {
        Info "（没有进行中的工单。已合并的工单归档在 main 的 $TicketsRel/）"
    } else {
        Info ("{0,-2} {1,-30} {2,-17} {3,-7} {4,-17} {5}" -f "", "工单", "状态", "持球", "更新", "最新消息")
        $mine = 0
        foreach ($d in $dirs) {
            $st = Get-TicketStatus $d
            $flag = ""
            if ($As -ne "" -and $st["owner"] -eq $As) { $flag = "★"; $mine++ }
            $note = ""
            if (-not (Test-RefExists "$Remote/tkt/$d")) { $note = "（未推送）" }
            $upd = [string]$st["updated"]
            if ($upd.Length -ge 16) { $upd = $upd.Substring(0, 16).Replace("T", " ") }
            Info ("{0,-2} {1,-30} {2,-17} {3,-7} {4,-17} {5}{6}" -f $flag, $d, $st["state"], $st["owner"], $upd, $st["message"], $note)
        }
        if ($As -ne "") { Info ""; Info "轮到 $As 的工单：$mine 张" }
    }

    Info ""
    $dirty = @(Get-DirtyPaths "")
    Info ("当前分支：{0}   未提交改动：{1} 处" -f $cur, $dirty.Count)
    if ($cur -ne "" -and (Test-RefExists "$Remote/$cur")) {
        $ab = Get-GitLine @("rev-list", "--left-right", "--count", "$cur...$Remote/$cur")
        if ($ab -match '^(\d+)\s+(\d+)$') {
            if ([int]$Matches[2] -gt 0) { Warn ("本地 $cur 落后远端 {0} 个提交（collab open 可快进）" -f $Matches[2]) }
            if ([int]$Matches[1] -gt 0) { Info ("本地 $cur 领先远端 {0} 个提交（未推送）" -f $Matches[1]) }
        }
    }
    if ((Test-RefExists "main") -and (Test-RefExists "$Remote/main")) {
        $behind = Get-GitLine @("rev-list", "--count", "main..$Remote/main")
        if ($behind -ne "" -and [int]$behind -gt 0) { Info "本地 main 落后 $Remote/main $behind 个提交" }
    }

    # still-here 新鲜度检查：WIP 存档之后又有提交或未提交改动 → 可能过期
    if ($As -ne "" -and $cur.StartsWith("tkt/")) {
        $d = $cur.Substring(4)
        $wipRel = "$TicketsRel/$d/WIP-$As.md"
        if (Test-Path -LiteralPath (Join-Path $Root $wipRel)) {
            $last = Get-GitLine @("log", "-1", "--format=%H", "--", $wipRel)
            $after = 0
            if ($last -ne "") { $after = [int](Get-GitLine @("rev-list", "--count", "$last..HEAD")) }
            Info ""
            if ($after -gt 0 -or $dirty.Count -gt 0) {
                Warn "WIP 存档 $wipRel 可能已过期：它之后又有 $after 个提交、$($dirty.Count) 处未提交改动。先核对实际状态（git log、git status），不要盲信存档。"
            } else {
                Info "有 WIP 存档：$wipRel（上次会话中途结束，先读它）"
            }
        }
    }
}

function Cmd-New {
    if ($Slug -notmatch '^[a-z0-9][a-z0-9-]{1,40}$') { Fail "-Slug 只能用小写英文、数字、连字符（2-41 字符），例如 -Slug user-login" }
    Invoke-Fetch
    if (-not (Test-RefExists "$Remote/main")) { Fail "远端还没有 main 分支。" }
    Assert-Clean "建工单前需要干净的工作区"
    $max = 0
    $names = @(Get-AllTicketDirs)
    $names += @(Invoke-GitOut @("ls-tree", "--name-only", "$Remote/main", "$TicketsRel/") -AllowFail | ForEach-Object { Split-Path $_ -Leaf })
    foreach ($n in $names) { if ($n -match '^T-(\d+)') { if ([int]$Matches[1] -gt $max) { $max = [int]$Matches[1] } } }
    $dir = ("T-{0:D4}-" -f ($max + 1)) + $Slug
    $base = Get-GitLine @("rev-parse", "$Remote/main")
    [void](Invoke-GitRun @("switch", "-q", "--no-track", "-c", "tkt/$dir", "$Remote/main"))
    $dirAbs = Join-Path $Root "$TicketsRel/$dir"
    New-Item -ItemType Directory -Force -Path $dirAbs | Out-Null
    $vars = @{ TICKET = $dir; DATE = (Get-Now); FROM = "claude"; BASE = $base; BRANCH = "tkt/$dir"; CODE_HEAD = ""; REVIEWED_HEAD = "" }
    Expand-Template "ticket" (Join-Path $dirAbs "00-ticket.md") $vars
    $st = [ordered]@{ ticket = $dir; state = "draft"; owner = "claude"; by = "claude"; updated = (Get-Now); message = "00-ticket.md"; base = $base; code_head = ""; reviewed_head = ""; resume = ""; rework = "0" }
    Write-StatusFile (Join-Path $dirAbs "STATUS") $st
    Ok "已建工单 $dir（分支 tkt/$dir，基于 origin/main $(Short $base)）"
    Info "下一步：填写 $TicketsRel/$dir/00-ticket.md，然后："
    Info "  scripts\collab.cmd send -To dispatched -As claude"
}

function Cmd-Open {
    $dir = Resolve-Ticket $Ticket
    Invoke-Fetch
    $branch = "tkt/$dir"
    $cur = Get-CurrentBranch
    if ($cur -ne $branch) {
        Assert-Clean "切换分支前需要干净的工作区"
        if (Test-RefExists "refs/heads/$branch") { [void](Invoke-GitRun @("switch", "-q", $branch)) }
        else { [void](Invoke-GitRun @("switch", "-q", "--track", "$Remote/$branch")) }
    }
    if (Test-RefExists "$Remote/$branch") {
        $code = Invoke-GitRun @("merge", "--ff-only", "-q", "$Remote/$branch") -AllowFail
        if ($code -ne 0) { Fail "本地 $branch 与远端分叉，无法快进。违反了球权规则？请人工检查（git log --graph --oneline $branch $Remote/$branch）。" }
    }
    Show-Ticket $dir
    $st = Get-TicketStatus $dir
    if ($As -ne "" -and $st["owner"] -eq $As) { Info ""; Ok "球在你这里。" }
}

function Cmd-Msg {
    Assert-Role
    if ($MsgTypes -notcontains $Type) { Fail ("-Type 必须是：" + ($MsgTypes -join ", ")) }
    $dir = Resolve-Ticket $Ticket
    Assert-OnTicketBranch $dir
    $dirAbs = Join-Path $Root "$TicketsRel/$dir"
    $max = -1
    foreach ($m in (Get-Messages $dirAbs)) { $n = [int]$m.Substring(0, 2); if ($n -gt $max) { $max = $n } }
    $name = ("{0:D2}-{1}.md" -f ($max + 1), $Type)
    $st = Get-TicketStatus $dir
    $vars = @{ TICKET = $dir; DATE = (Get-Now); FROM = $As; BASE = $st["base"]; BRANCH = "tkt/$dir"; CODE_HEAD = $st["code_head"]; REVIEWED_HEAD = $st["reviewed_head"] }
    Expand-Template $Type (Join-Path $dirAbs $name) $vars
    Ok "已生成 $TicketsRel/$dir/$name"
}

function Cmd-Send {
    Assert-Role
    if ($To -eq "") { Fail "请用 -To 指定目标状态。" }
    $dir = Resolve-Ticket $Ticket
    Assert-OnTicketBranch $dir
    $branch = "tkt/$dir"
    $dirRel = "$TicketsRel/$dir"
    $dirAbs = Join-Path $Root $dirRel
    $statusAbs = Join-Path $dirAbs "STATUS"
    if (-not (Test-Path -LiteralPath $statusAbs)) { Fail "找不到 $dirRel/STATUS。" }
    $st = Read-StatusText ([System.IO.File]::ReadAllText($statusAbs, $Utf8))
    $from = [string]$st["state"]
    Test-Transition $from $To $As

    # 远端没有本地没见过的提交（球权规则的机械校验）
    Invoke-Fetch
    if (Test-RefExists "$Remote/$branch") {
        $code = Invoke-GitRun @("merge-base", "--is-ancestor", "$Remote/$branch", "HEAD") -AllowFail
        if ($code -ne 0) { Fail "远端 $branch 有本地没有的提交（对方刚推送过？）。先 collab open 同步，再发送。" }
    }

    # 代码必须先提交：工单目录外不允许有未提交改动
    $outside = @(Get-DirtyPaths $dirRel)
    if ($outside.Count -gt 0) {
        Fail ("工单目录外有未提交改动。先把代码按原子提交提交好（[T-xxxx] ...），再 send：`n  " + (($outside | Select-Object -First 10) -join "`n  "))
    }

    # 消息：必须至少有一条新消息；已发送的消息不许改写
    $newMsgs = @()
    foreach ($l in @(Invoke-GitOut @("status", "--porcelain", "--untracked-files=all", "--", $dirRel))) {
        if ($l.Length -lt 4) { continue }
        $xy = $l.Substring(0, 2)
        $leaf = Split-Path ($l.Substring(3).Trim('"')) -Leaf
        if ($leaf -notmatch '^\d{2}-[a-z-]+\.md$') { continue }
        if ($xy -eq "??" -or $xy -eq "A ") { $newMsgs += $leaf }
        else { Fail "消息只追加不改写：$leaf 已经发送过（$xy）。要更正请发一条新消息。可用 git checkout -- $dirRel/$leaf 撤销改动。" }
    }
    if ($newMsgs.Count -eq 0) { Fail "没有新消息。先用 collab msg -Type <类型> -As $As 写一条，再 send。" }
    $newMsgs = @($newMsgs | Sort-Object)

    if ($from -eq "fix_done" -and $To -eq "rework_requested") {
        $rw = 0; [void][int]::TryParse([string]$st["rework"], [ref]$rw)
        if ($rw -ge $MaxRework) { Fail "已返工 $rw 次（上限 $MaxRework，协约 §4.5）。请转 blocked 交人类决定。" }
        $st["rework"] = [string]($rw + 1)
    }

    $head = Get-GitLine @("rev-parse", "HEAD")
    if ($As -eq "codex" -and @("impl_done", "fix_done", "test_done") -contains $To) { $st["code_head"] = $head }
    if ($As -eq "claude" -and @("impl_done", "fix_done") -contains $from) { $st["reviewed_head"] = $st["code_head"] }
    if ($To -eq "query") { $st["resume"] = $from }
    elseif ($from -eq "query") { $st["resume"] = "" }
    if (-not $st.Contains("rework")) { $st["rework"] = "0" }
    $st["state"] = $To
    $st["owner"] = $Owner[$To]
    $st["by"] = $As
    $st["updated"] = Get-Now
    $st["message"] = $newMsgs[-1]
    Write-StatusFile $statusAbs $st

    $wip = Join-Path $dirAbs "WIP-$As.md"
    if (Test-Path -LiteralPath $wip) { Remove-Item -LiteralPath $wip -Force }

    [void](Invoke-GitRun @("add", "-A", "--", $dirRel))
    $id = ($dir -split '-')[0..1] -join '-'
    New-Commit "[$id] ${To}: $($newMsgs -join ', ')" @("Ticket: $dir", "Collab-State: $from -> $To", "Collab-Actor: $As")
    if ($NoPush) {
        Warn "已提交但未推送（-NoPush）。对方要等你推送后才收得到：git push -u $Remote $branch"
    } else {
        [void](Invoke-GitRun @("push", "-q", "-u", $Remote, $branch))
    }
    Ok "已发送：$from → $To（$($newMsgs -join ', ')）。球现在在 $($Owner[$To])。"
}

function Cmd-Diff {
    $dir = Resolve-Ticket $Ticket
    $st = Get-TicketStatus $dir
    $head = [string]$st["code_head"]
    if ($head -eq "") { $head = "$Remote/tkt/$dir"; if (-not (Test-RefExists $head)) { $head = "tkt/$dir" } }
    if ($Since -eq "reviewed") {
        $base = [string]$st["reviewed_head"]
        if ($base -eq "") { Fail "还没有 reviewed_head（尚未审查过），去掉 -Since 看全量 diff。" }
        $label = "上次审查之后的改动（复审用）"
    } else {
        $base = Get-GitLine @("merge-base", "$Remote/main", $head)
        $label = "相对 main 的全部代码改动（/code-review 用）"
    }
    Info "工单 $dir：$label"
    Info ("  {0} .. {1}" -f (Short $base), (Short $head))
    [void](Invoke-GitRun @("diff", "--stat", "$base..$head", "--", ".", $CodeExclude))
    Info ""
    Info "完整 diff：git diff $base..$head -- . `"$CodeExclude`""
}

function Cmd-Wip {
    Assert-Role
    $dir = Resolve-Ticket $Ticket
    Assert-OnTicketBranch $dir
    $st = Get-TicketStatus $dir
    if ($st["owner"] -ne $As) { Fail "球不在你这里（持球 $($st['owner'])），不能向工单分支推送。" }
    $dirAbs = Join-Path $Root "$TicketsRel/$dir"
    $wip = Join-Path $dirAbs "WIP-$As.md"
    if (-not (Test-Path -LiteralPath $wip)) {
        Expand-Template "wip" $wip @{ TICKET = $dir; DATE = (Get-Now); FROM = $As; BASE = ""; BRANCH = "tkt/$dir"; CODE_HEAD = ""; REVIEWED_HEAD = "" }
        Ok "已生成 $TicketsRel/$dir/WIP-$As.md（覆盖式：每次整份重写）"
    }
    if (-not $Commit) {
        Info "写好后提交并推送：scripts\collab.cmd wip -As $As -Commit"
        return
    }
    [void](Invoke-GitRun @("add", "-A"))
    $id = ($dir -split '-')[0..1] -join '-'
    New-Commit "[$id] wip: $As 交接存档" @("Ticket: $dir", "Collab-Actor: $As")
    if (-not $NoPush) { [void](Invoke-GitRun @("push", "-q", "-u", $Remote, "tkt/$dir")) }
    Ok "WIP 已提交$(if (-not $NoPush) { '并推送' })。"
}

function Cmd-Merge {
    $dir = Resolve-Ticket $Ticket
    $branch = "tkt/$dir"
    Invoke-Fetch
    $st = Get-TicketStatus $dir
    if ($st["state"] -ne "accepted") { Fail "只有 accepted 的工单能合并（当前 $($st['state'])）。" }
    $tip = "$Remote/$branch"
    if (-not (Test-RefExists $tip)) { $tip = $branch }
    Info "将以 --no-ff 合入 main 的提交："
    [void](Invoke-GitRun @("log", "--oneline", "$Remote/main..$tip"))
    [void](Invoke-GitRun @("diff", "--stat", "$Remote/main...$tip", "--", ".", $CodeExclude))
    if (-not $Push) {
        Info ""
        Warn "以上为预览，未做任何改动。推送 main 需要用户确认（协约 §4.9）。确认后执行："
        Info "  scripts\collab.cmd merge -Ticket $dir -Push"
        return
    }
    Assert-Clean "合并前需要干净的工作区"
    $cur = Get-CurrentBranch
    if ($cur -ne $branch) {
        if (Test-RefExists "refs/heads/$branch") { [void](Invoke-GitRun @("switch", "-q", $branch)) }
        else { [void](Invoke-GitRun @("switch", "-q", "--track", "$Remote/$branch")) }
    }
    if (Test-RefExists "$Remote/$branch") { [void](Invoke-GitRun @("merge", "--ff-only", "-q", "$Remote/$branch")) }
    $statusAbs = Join-Path $Root "$TicketsRel/$dir/STATUS"
    $st = Read-StatusText ([System.IO.File]::ReadAllText($statusAbs, $Utf8))
    $st["state"] = "merged"; $st["owner"] = "none"; $st["by"] = "claude"; $st["updated"] = Get-Now
    Write-StatusFile $statusAbs $st
    [void](Invoke-GitRun @("add", "--", "$TicketsRel/$dir/STATUS"))
    $id = ($dir -split '-')[0..1] -join '-'
    New-Commit "[$id] merged" @("Ticket: $dir", "Collab-State: accepted -> merged", "Collab-Actor: claude")
    if (Test-RefExists "refs/heads/main") { [void](Invoke-GitRun @("switch", "-q", "main")) }
    else { [void](Invoke-GitRun @("switch", "-q", "--track", "$Remote/main")) }
    [void](Invoke-GitRun @("merge", "--ff-only", "-q", "$Remote/main"))
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, "[$id] 合并工单 $dir`n`nTicket: $dir`n", $Utf8)
    try { [void](Invoke-GitRun @("merge", "--no-ff", "-q", "-F", $tmp, $branch)) }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    [void](Invoke-GitRun @("push", "-q", $Remote, "main"))
    [void](Invoke-GitRun @("push", "-q", $Remote, "--delete", $branch) -AllowFail)
    [void](Invoke-GitRun @("branch", "-q", "-d", $branch) -AllowFail)
    Ok "工单 $dir 已合入 main 并推送，远端工单分支已删除。"
}

function Cmd-FixNote {
    if ($Summary -eq "" -or $Why -eq "") { Fail "需要 -Summary <摘要> 和 -Why <为什么属于 A 级>。" }
    $fix = Join-Path $Root "FIXLOG.md"
    if (-not (Test-Path -LiteralPath $fix)) { Fail "找不到 FIXLOG.md" }
    $f = $Files
    if ($f -eq "") {
        $f = (@(Invoke-GitOut @("diff", "--name-only")) + @(Invoke-GitOut @("diff", "--cached", "--name-only")) | Sort-Object -Unique) -join ", "
    }
    $cur = Get-CurrentBranch
    $tk = "无"
    if ($cur.StartsWith("tkt/")) { $tk = $cur.Substring(4) }
    $entry = "`n## $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  [A 级自治修复]`n`n- 工单：$tk`n- 摘要：$Summary`n- 文件：$f`n- 为什么属于 A 级（确定性、局部、不改契约）：$Why`n"
    [System.IO.File]::AppendAllText($fix, $entry, $Utf8)
    Ok "已记入 FIXLOG.md。单独提交："
    Info "  git add <文件> FIXLOG.md"
    Info "  git commit -m `"[autofix] $Summary`""
}

switch ($Command.ToLower()) {
    "help"    { Cmd-Help }
    "setup"   { Cmd-Setup }
    "inbox"   { Cmd-Inbox }
    "status"  { Cmd-Inbox }
    "new"     { Cmd-New }
    "open"    { Cmd-Open }
    "msg"     { Cmd-Msg }
    "send"    { Cmd-Send }
    "diff"    { Cmd-Diff }
    "wip"     { Cmd-Wip }
    "merge"   { Cmd-Merge }
    "fixnote" { Cmd-FixNote }
    default   { Cmd-Help; Fail "未知命令：$Command" }
}
exit 0
