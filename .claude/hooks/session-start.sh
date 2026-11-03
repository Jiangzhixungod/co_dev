#!/usr/bin/env bash
#
# SessionStart hook（still-here 的 co_dev 适配版）：
#   1. 注入 Claude 的任务书，并在它可能过期时给出警告；
#   2. 附上协作收件箱的本地快照（不联网，开工前仍需跑 collab inbox 拉取）。
#
# 输出纯文本：SessionStart 的 stdout 会作为上下文交给 Claude，因此不需要 jq。
# 任何一步出错都必须静默，不能让会话起不来。
#
# 过期检查不判断"上一轮有没有收口"，只报两个事实，让新会话自己核对：
#   任务书最后一次更新之后 main 上又有几个提交；工作区有几处未提交改动。
set -u

# Windows Git Bash 会把 "origin/tkt/x:path" 这类参数当成路径列表改写成 "origin\tkt\x;path"，
# 导致 git show 读不到文件。关闭 MSYS 的参数转换（其他平台上这两个变量无影响）。
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

root="${CLAUDE_PROJECT_DIR:-.}"
rel="docs/handover/next-session-prompt.md"
file="$root/$rel"

in_git=0
git -C "$root" rev-parse --git-dir >/dev/null 2>&1 && in_git=1

if [ -f "$file" ]; then
  if [ "$in_git" = 1 ]; then
    last="$(git -C "$root" log -1 --format=%H -- "$rel" 2>/dev/null || true)"
    if [ -n "$last" ]; then
      ref=HEAD
      git -C "$root" rev-parse --verify -q main >/dev/null 2>&1 && ref=main
      after="$(git -C "$root" rev-list --count "$last..$ref" 2>/dev/null || echo 0)"
      dirty="$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
      if [ "${after:-0}" -gt 0 ] || [ "${dirty:-0}" -gt 0 ]; then
        cat <<EOF
⚠️ 任务书可能已过期：它最后一次更新之后，$ref 上又有 ${after} 个提交，工作区有 ${dirty} 处未提交改动。

上一轮很可能**没有收口**（用户直接关掉了对话）。下面这份任务书描述的，可能是**已经做完的事**。
**开工前先核对实际状态**：scripts/collab.cmd inbox -As claude、git log --oneline -15、交接件最后一个 ## 0x 节。
**不要盲信下面的内容。** 确认过期后，先把它更新到当前状态，再开始干活。

EOF
      fi
    fi
  fi
  echo "=== 交接工作流：本轮任务书 $rel（已自动载入，不必再读一遍）==="
  echo
  cat "$file"
  echo
fi

if [ "$in_git" = 1 ]; then
  # 模式：git config collab.mode；未设置时有 origin 远端即 remote，否则 local（与 scripts/collab.ps1 一致）
  mode="$(git -C "$root" config collab.mode 2>/dev/null || true)"
  if [ "$mode" != local ] && [ "$mode" != remote ]; then
    if git -C "$root" remote get-url origin >/dev/null 2>&1; then mode=remote; else mode=local; fi
  fi
  if [ "$mode" = local ]; then
    echo "=== 协作收件箱（本地模式：同机同仓库，工作区共享）。开工前先跑 scripts/collab.cmd inbox -As claude ==="
    refs_root=refs/heads/tkt/; prefix=tkt/
  else
    echo "=== 协作收件箱：本地快照（未联网）。开工前先跑 scripts/collab.cmd inbox -As claude 拉取最新 ==="
    refs_root=refs/remotes/origin/tkt/; prefix=origin/tkt/
  fi
  cur="$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  n=0
  for ref in $(git -C "$root" for-each-ref --format='%(refname:short)' "$refs_root" 2>/dev/null); do
    dir="${ref#"$prefix"}"
    if [ "$mode" = local ] && [ "$cur" = "tkt/$dir" ] && [ -f "$root/.ai-collab/tickets/$dir/STATUS" ]; then
      st="$(tr -d '\r' < "$root/.ai-collab/tickets/$dir/STATUS")"
    else
      st="$(git -C "$root" show "$ref:.ai-collab/tickets/$dir/STATUS" 2>/dev/null | tr -d '\r')"
    fi
    state="$(printf '%s\n' "$st" | sed -n 's/^state: *//p')"
    owner="$(printf '%s\n' "$st" | sed -n 's/^owner: *//p')"
    mark="  "
    [ "$owner" = "claude" ] && mark="★ "
    printf '%s%-30s %-17s 持球 %s\n' "$mark" "$dir" "$state" "$owner"
    n=$((n + 1))
  done
  [ "$n" = 0 ] && echo "（本地快照里没有进行中的工单）"
fi
exit 0
