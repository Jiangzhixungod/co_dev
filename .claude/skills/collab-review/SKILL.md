---
name: collab-review
description: 审查 Codex 提交的代码。impl_done 时跑唯一一轮 /code-review；fix_done 时由主 agent 亲自复审（不再跑 /code-review）。用户说"Codex 编码完成了""修好了""审一下 T-xxxx"，或 inbox 显示 impl_done / fix_done 轮到 claude 时使用。
---

# 代码审查（协约 §4.3、§4.5）

```
scripts/collab.cmd open -Ticket T-NNNN -As claude
```

按序号读完工单目录下的全部消息，再看 STATUS 里的状态。

## A. 状态是 `impl_done`：/code-review，全程仅此一轮

1. `scripts/collab.cmd diff` 查看待审范围（`origin/main...code_head`，不含工单目录）。
2. 运行 `/code-review high tkt/T-NNNN-<slug>`（档位默认 high；用户另有指定就照用户的）。
3. 对照 `00-ticket.md` 的范围与验收标准，补看 `/code-review` 不覆盖的东西：是否偏离工单、是否越界改了受保护路径、自测证据是否真实。
4. `scripts/collab.cmd msg -Type code-review -As claude`，写入结论、发现清单、**必改项 F1…**（每条可独立验证）、建议测试。
5. 发送：
   - 有必改项：`send -To fix_requested -As claude`
   - 无必改项：`send -To review_passed -As claude`；或接着用 `/collab-testplan` 写测试方案，然后直接 `send -To test_dispatched`

## B. 状态是 `fix_done`：主 agent 复审（**不要再跑 /code-review**）

1. `scripts/collab.cmd diff -Since reviewed` 查看上次审查之后的改动。
2. **亲自读 diff**，对照上一份 code-review / re-review / report-review 的每个 F / R 编号，逐条判断是否**真正**关闭（看代码，必要时读相关上下文）。再检查修复有没有引入新问题。
3. `msg -Type re-review -As claude`，逐条写核对结果。
4. 发送：
   - 全部关闭：`send -To test_dispatched`（附测试方案，用 `/collab-testplan`）或 `send -To review_passed`
   - 仍有问题：`send -To rework_requested`（脚本限制最多 2 次；超出时转 `blocked`，用大白话向用户说明情况并给出建议）

## 结束

向用户汇报：结论、必改项数量、球现在在谁手里。
