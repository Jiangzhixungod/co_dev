#!/usr/bin/env bash
#
# collab 端到端回归测试：在一台机器上模拟 "Claude 机器" 与 "Codex 机器"，把整套工单状态机走一遍。
# 改动 scripts/collab.ps1、scripts/git-hooks/、.claude/hooks/ 之后必须跑通。
#
#   bash scripts/tests/collab-e2e.sh [工作目录]        （Windows 上用 Git Bash 运行）
#
# harness 边界
#   SUT        scripts/collab.cmd + collab.ps1（Windows PowerShell 5.1）、scripts/git-hooks/commit-msg、
#              .claude/hooks/session-start.sh；被测的是本仓库当前 HEAD（未提交的改动不在测试范围内）
#   替身       GitHub → 本地裸仓库 remote.git；两台机器 → 两个克隆 claude/、codex/
#   真实运行   git、PowerShell、Git Bash；不联网
#   隔离       每次在全新的工作目录里重建，不碰本仓库与 ~/.ssh
#   观测点     命令退出码、命令输出、STATUS 文件、远端分支与 main 的内容
#   判据       全部 PASS；任何 FAIL 时以退出码 1 结束
set -u
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

# 关闭了 MSYS 路径转换，所以传给 git 的必须是原生路径：Git Bash 下用 pwd -W（C:/...），其他平台退回 pwd
native_pwd() { pwd -W 2>/dev/null || pwd; }
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && native_pwd)"
E="${1:-${TMPDIR:-/tmp}/collab-e2e}"
rm -rf "$E" && mkdir -p "$E" && cd "$E" || exit 2
E="$(native_pwd)"

git clone -q --bare "$SRC" remote.git || exit 2
for r in claude codex; do
  git clone -q remote.git "$r" || exit 2
  (cd "$r" && git config user.name "sim-$r" && git config user.email "$r@sim.local" \
     && ./scripts/collab.cmd setup >/dev/null) || exit 2
done

C=./scripts/collab.cmd
pass=0; fail=0
_report() { # _report <ok?> <描述> <输出>
  if [ "$1" = 1 ]; then pass=$((pass + 1)); echo "PASS  $2"
  else fail=$((fail + 1)); echo "FAIL  $2"; printf '%s\n' "$3" | sed 's/^/        /' | head -20; fi
}
ok()  { local d="$1"; shift; local o; o="$("$@" 2>&1)"; local rc=$?; _report "$([ $rc -eq 0 ] && echo 1)" "$d" "exit=$rc
$o"; }
no()  { local d="$1" p="$2"; shift 2; local o; o="$("$@" 2>&1)"; local rc=$?
        _report "$([ $rc -ne 0 ] && printf '%s' "$o" | grep -q -- "$p" && echo 1)" "$d" "exit=$rc（期望失败且输出含 /$p/）
$o"; }
has() { local d="$1" p="$2"; shift 2; local o; o="$("$@" 2>&1)"
        _report "$(printf '%s' "$o" | grep -q -- "$p" && echo 1)" "$d" "输出不含 /$p/：
$o"; }
lacks() { local d="$1" p="$2"; shift 2; local o; o="$("$@" 2>&1)"
        _report "$(printf '%s' "$o" | grep -q -- "$p" || echo 1)" "$d" "输出不应含 /$p/：
$o"; }
on()  { cd "$E/$1" || exit 2; }
T1=.ai-collab/tickets/T-0001-hello

echo "== 派单 =="
on claude
ok   "claude 建工单 T-0001"                        $C new -Slug hello
has  "新工单为 draft"                              "state: draft" cat $T1/STATUS
no   "非法 slug 被拒"                              "只能用小写" $C new -Slug Bad_Slug
ok   "派单 draft→dispatched"                       $C send -To dispatched -As claude

echo "== 编码 =="
on codex
has  "codex 收件箱 ★"                             "★  T-0001-hello" $C inbox -As codex
ok   "codex 打开工单"                              $C open -Ticket 1 -As codex
mkdir -p src && echo 'print("hello")' > src/hello.py
no   "代码未提交时 send 被拒"                      "未提交改动" $C send -To impl_done -As codex
git add src && git commit -qm "[T-0001] 新增 hello"
no   "没有新消息时 send 被拒"                      "没有新消息" $C send -To impl_done -As codex
ok   "生成 impl-report"                            $C msg -Type impl-report -As codex
has  "消息序号为 01"                               "01-impl-report.md" ls $T1
ok   "交付 dispatched→impl_done"                   $C send -To impl_done -As codex
has  "记录 code_head"                              "code_head: [0-9a-f]\{40\}" cat $T1/STATUS
no   "球已交出后 codex 再 send 被拒"               "球在 claude" $C send -To fix_done -As codex

echo "== 审查（/code-review 一轮）=="
on claude
has  "停在落后的本地分支时 inbox 仍以远端为准"     "★  T-0001-hello  *impl_done" $C inbox -As claude
ok   "claude 打开工单"                             $C open -Ticket 1 -As claude
has  "diff 只含代码"                               "src/hello.py" $C diff
lacks "diff 不含工单目录"                          "tickets" git diff --stat origin/main...HEAD -- . ":(exclude).ai-collab/tickets"
echo x >> $T1/00-ticket.md
ok   "生成 code-review"                            $C msg -Type code-review -As claude
no   "改写已发送的消息被拒"                        "只追加不改写" $C send -To fix_requested -As claude
git checkout -q -- $T1/00-ticket.md
no   "非法转移 impl_done→test_done 被拒"           "非法转移" $C send -To test_done -As claude
no   "codex 不能代 claude 发送"                    "球在 claude" $C send -To fix_requested -As codex
ok   "审查不过 impl_done→fix_requested"            $C send -To fix_requested -As claude
has  "记录 reviewed_head"                          "reviewed_head: [0-9a-f]\{40\}" cat $T1/STATUS

echo "== 质询 =="
on codex
ok   "codex 打开"                                  $C open -Ticket 1 -As codex
ok   "生成 query"                                  $C msg -Type query -As codex
ok   "发起质询 fix_requested→query"                $C send -To query -As codex
has  "记住质询前状态"                              "resume: fix_requested" cat $T1/STATUS
on claude
ok   "claude 打开"                                 $C open -Ticket 1 -As claude
ok   "生成 resolution"                             $C msg -Type resolution -As claude
no   "裁决后不能去 claude 持球状态"                "只能回到 Codex" $C send -To review_passed -As claude
ok   "裁决 query→fix_requested"                    $C send -To fix_requested -As claude

echo "== 修复 + 主 agent 复审（返工上限 2）=="
for i in 1 2 3; do
  on codex
  ok "codex 第 $i 次修复：打开"                    $C open -Ticket 1 -As codex
  echo "# fix $i" >> src/hello.py && git commit -qam "[T-0001] 修复 $i"
  ok "codex 第 $i 次修复：fix-report"              $C msg -Type fix-report -As codex
  ok "codex 第 $i 次修复：→fix_done"               $C send -To fix_done -As codex
  on claude
  ok "claude 第 $i 次复审：打开"                   $C open -Ticket 1 -As claude
  has "复审 diff 只看上次审查之后"                 "上次审查之后" $C diff -Since reviewed
  ok "claude 第 $i 次复审：re-review"              $C msg -Type re-review -As claude
  if [ $i -lt 3 ]; then
    ok "第 $i 次返工 fix_done→rework_requested"    $C send -To rework_requested -As claude
    has "返工计数 = $i"                            "rework: $i" cat $T1/STATUS
  else
    no "第 3 次返工被拒（上限 2）"                 "已返工 2 次" $C send -To rework_requested -As claude
  fi
done
ok   "生成 test-plan"                              $C msg -Type test-plan -As claude
ok   "复审通过 + 测试方案一起发 →test_dispatched"  $C send -To test_dispatched -As claude

echo "== 测试 + WIP 存档（still-here）=="
on codex
ok   "codex 打开"                                  $C open -Ticket 1 -As codex
ok   "生成 WIP 存档"                               $C wip -As codex
mkdir -p tests && echo "def test_a(): pass" > tests/test_hello.py
ok   "WIP 提交并推送"                              $C wip -As codex -Commit
has  "inbox 提示有 WIP 存档"                       "有 WIP 存档" $C inbox -As codex
echo "def test_b(): pass" >> tests/test_hello.py && git commit -qam "[T-0001] 补测试"
has  "WIP 之后有新提交 → 提示可能过期"             "可能已过期" $C inbox -As codex
echo "# typo" >> src/hello.py
ok   "A 级修复记入 FIXLOG"                         $C fixnote -Summary "修正注释" -Why "只改注释"
git add src FIXLOG.md && git commit -qm "[autofix] 修正注释"
mkdir -p docs/testing/T-0001-hello && echo "2 passed" > docs/testing/T-0001-hello/unit.log
git add docs/testing && git commit -qm "[T-0001] 测试日志"
has  "测试日志 *.log 未被忽略"                     "unit.log" git ls-files docs/testing
ok   "生成 test-report"                            $C msg -Type test-report -As codex
ok   "交付 test_dispatched→test_done"              $C send -To test_done -As codex
_report "$([ ! -e $T1/WIP-codex.md ] && echo 1)" "发出正式消息后 WIP 存档自动删除" "WIP-codex.md 仍存在"

echo "== 验收 + 合并 =="
on claude
ok   "claude 打开"                                 $C open -Ticket 1 -As claude
ok   "生成 report-review"                          $C msg -Type report-review -As claude
no   "send 不能直接到 merged"                      "只能通过 collab merge" $C send -To merged -As claude
ok   "验收 test_done→accepted"                     $C send -To accepted -As claude
has  "merge 不带 -Push 只预览"                     "以上为预览" $C merge -Ticket 1
has  "预览后远端工单分支仍在"                      "tkt/T-0001-hello" git ls-remote --heads origin
ok   "merge -Push"                                 $C merge -Ticket 1 -Push
lacks "合并后远端工单分支已删除"                   "tkt/" git ls-remote --heads origin
has  "main 上归档 STATUS = merged"                 "state: merged" git show origin/main:$T1/STATUS
has  "main 上有代码"                               "hello" git show origin/main:src/hello.py

on codex
has  "codex 停在已合并分支：提示切回 main"         "已合入 main" $C inbox -As codex
git switch -q main && git pull -q
has  "切回 main 后清理残留分支"                    "已清理本地分支" $C inbox -As codex

echo "== 并发两张工单 =="
on claude
git switch -q main && git pull -q
ok   "建 T-0002"                                   $C new -Slug alpha
has  "未发送的草稿不会被当成已合并清理"            "T-0002-alpha" $C inbox -As claude
ok   "派 T-0002"                                   $C send -To dispatched -As claude
git switch -q main
ok   "建并派 T-0003"                               $C new -Slug beta
ok   "派 T-0003"                                   $C send -To dispatched -As claude
on codex
for t in 2 3; do
  ok "codex 不先跑 inbox 也能 open T-000$t"        $C open -Ticket $t -As codex
  echo "x$t" > "f$t.txt"
  ok "T-000$t：A 级修复记入 FIXLOG"                $C fixnote -Summary "fix $t" -Why "trivial"
  git add "f$t.txt" FIXLOG.md && git commit -qm "[autofix] fix $t"
  ok "T-000$t：impl-report"                        $C msg -Type impl-report -As codex
  ok "T-000$t：→impl_done"                         $C send -To impl_done -As codex
done
on claude
for t in 2 3; do
  ok "T-000$t：打开"                               $C open -Ticket $t -As claude
  ok "T-000$t：report-review"                      $C msg -Type report-review -As claude
  ok "T-000$t：→accepted（文档类直通）"            $C send -To accepted -As claude
  ok "T-000$t：merge -Push"                        $C merge -Ticket $t -Push
done
n="$(git show origin/main:FIXLOG.md | grep -c '^## 20')"
_report "$([ "$n" = 3 ] && echo 1)" "FIXLOG 两张工单并发追加，合并后 3 条都在（union）" "实际 $n 条"

echo "== SessionStart hook（still-here）=="
ok   "建并派 T-0004"                               $C new -Slug gamma
ok   "派 T-0004"                                   $C send -To dispatched -As claude
git switch -q main
H="$(CLAUDE_PROJECT_DIR="$E/claude" bash .claude/hooks/session-start.sh 2>&1)"
has  "hook 注入任务书"                             "本轮任务书" printf '%s' "$H"
has  "hook 任务书之后有新提交 → 过期警告"          "任务书可能已过期" printf '%s' "$H"
has  "hook 收件箱显示 origin/tkt/* 的状态"         "T-0004-gamma *dispatched *持球 codex" printf '%s' "$H"

echo "== 取消工单（Codex 拉取后自动收口）=="
on claude
ok   "建 T-0005"                                   $C new -Slug delta
ok   "派 T-0005"                                   $C send -To dispatched -As claude
git switch -q main
on codex
ok   "codex 打开 T-0005（留下本地分支）"           $C open -Ticket 5 -As codex
git switch -q main
ok   "codex 打开 T-0004"                           $C open -Ticket 4 -As codex
echo "wip" > g4.txt && git add g4.txt && git commit -qm "[T-0004] 未推送的半成品"
on claude
for t in 4 5; do
  ok "T-000$t：claude 打开"                        $C open -Ticket $t -As claude
  ok "T-000$t：取消说明 note"                      $C msg -Type note -As claude
  ok "T-000$t：claude →cancelled"                  $C send -To cancelled -As claude
done
has  "远端 STATUS = cancelled"                     "state: cancelled" git show origin/tkt/T-0005-delta:.ai-collab/tickets/T-0005-delta/STATUS
git switch -q main
on codex
I="$($C inbox -As codex 2>&1)"
has  "停在已取消分支：提示停止并切回 main"         "T-0004-gamma 已被取消：停止该工单" printf '%s' "$I"
has  "不在其上的已取消分支：自动清理"              "已清理本地分支 tkt/T-0005-delta（该工单已取消）" printf '%s' "$I"
has  "已取消工单单独列出"                          "已取消（已结束，无需处理）：T-0004-gamma, T-0005-delta" printf '%s' "$I"
lacks "已取消工单不再标 ★"                         "★" printf '%s' "$I"
lacks "T-0005 本地分支已删除"                      "T-0005" git branch --list "tkt/*"
no   "已取消工单：codex 旧分支 send 被拒"          "有本地没有的提交" $C send -Ticket 4 -To impl_done -As codex
git switch -q main
has  "有未推送提交的已取消分支：保留并提示"        "有 1 个未推送提交，未自动清理" $C inbox -As codex
has  "T-0004 本地分支仍在"                         "T-0004" git branch --list "tkt/*"
git branch -q -D tkt/T-0004-gamma

echo "== commit-msg 护栏 =="
on codex
echo "" >> AGENTS.md
no   "改受保护路径且无 trailer → 拒绝"             "BLOCKED" git commit -qam "改协约"
ok   "带 Override trailer → 放行"                  git commit -qam "改协约" -m "Override: e2e"

echo "== 本地模式（同机同仓库，无远端）=="
git clone -q "$E/remote.git" "$E/local" || exit 2
on local
git remote remove origin
git config user.name "sim-local" && git config user.email "local@sim.local"
has  "setup -Mode local"                           "模式：local" $C setup -Mode local
L=.ai-collab/tickets/T-0004-local-sort
ok   "claude 建工单（编号接着 main 上的归档）"     $C new -Slug local-sort
has  "本地模式派单：提交即送达，不推送"            "提交即送达" $C send -To dispatched -As claude
has  "codex 同目录 inbox ★"                        "★  T-0004-local-sort" $C inbox -As codex
no   "codex 持球时 claude 建新单被拒（工作区共享）" "正由 codex 持球" $C new -Slug other
ok   "codex 打开（已在该分支上）"                  $C open -Ticket 4 -As codex
mkdir -p src && echo 'x = 1' > src/local.py && git add src && git commit -qm "[T-0004] 本地模式编码"
ok   "codex impl-report"                           $C msg -Type impl-report -As codex
ok   "codex →impl_done"                            $C send -To impl_done -As codex
has  "claude 同目录 inbox ★"                       "★  T-0004-local-sort *impl_done" $C inbox -As claude
has  "本地模式 diff 以本地 main 为基"              "src/local.py" $C diff
ok   "claude code-review + test-plan"              $C msg -Type code-review -As claude
ok   "claude test-plan"                            $C msg -Type test-plan -As claude
ok   "claude →test_dispatched"                     $C send -To test_dispatched -As claude
ok   "codex test-report"                           $C msg -Type test-report -As codex
ok   "codex →test_done"                            $C send -To test_done -As codex
ok   "claude report-review"                        $C msg -Type report-review -As claude
ok   "claude →accepted"                            $C send -To accepted -As claude
has  "本地模式 merge 预览"                         "合入本地 main" $C merge -Ticket 4
has  "本地模式 merge 执行"                         "已合入本地 main" $C merge -Ticket 4 -Push
lacks "合并后本地工单分支已删除"                   "tkt/" git branch --list "tkt/*"
has  "main 上归档 STATUS = merged"                 "state: merged" git show main:$L/STATUS
ok   "建 T-0005"                                   $C new -Slug next
ok   "派 T-0005"                                   $C send -To dispatched -As claude
git switch -q main
no   "本地模式下需要切分支时 open 必须带 -As"      "请用 -As" $C open -Ticket 5
ok   "codex open -As codex"                        $C open -Ticket 5 -As codex
H="$(CLAUDE_PROJECT_DIR="$E/local" bash .claude/hooks/session-start.sh 2>&1)"
has  "hook 识别本地模式"                           "本地模式" printf '%s' "$H"
has  "hook 本地模式显示工单状态"                   "T-0005-next *dispatched *持球 codex" printf '%s' "$H"

echo
echo "结果：PASS $pass  FAIL $fail    （工作目录 $E）"
[ "$fail" -eq 0 ]
