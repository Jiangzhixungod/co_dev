---
name: collab-review
description: 审查 Codex 提交的代码。impl_done 时跑唯一一轮 /code-review，并对其每条发现分诊（只有真实且有影响的才派修复）；fix_done 时由主 agent 亲自复审（不再跑 /code-review）。用户说"Codex 编码完成了""修好了""审一下 T-xxxx"，或 inbox 显示 impl_done / fix_done 轮到 claude 时使用。
---

# 代码审查（协约 §4.3、§4.5）

```
scripts/collab.cmd open -Ticket T-NNNN -As claude
```

`open` 会先拉取远端，再切到工单分支并快进到最新，不需要另外 pull。
按序号读完工单目录下的全部消息，再看 STATUS 里的状态。

## A. 状态是 `impl_done`：/code-review，全程仅此一轮

1. `scripts/collab.cmd diff` 查看待审范围（`origin/main...code_head`，不含工单目录）。
2. **先自己通读代码**，对照 `00-ticket.md` 的范围与验收标准：有没有偏离工单、有没有越界改受保护路径、自测证据是否真实（关键结论在本机复现一下）。
3. 运行 `/code-review high tkt/T-NNNN-<slug>`（档位默认 high；用户另有指定就照用户的）。
4. **分诊：逐条分析 /code-review 的发现，不能原样转发给 Codex。**（见下节）
5. `scripts/collab.cmd msg -Type code-review -As claude`：写结论、**含处置列的发现清单**、必改项 F1…（每条可独立验证）、契约澄清、建议测试。
6. 发送：
   - 有必改项：`send -To fix_requested -As claude`
   - 无必改项：`send -To review_passed -As claude`；或接着用 `/collab-testplan` 写测试方案，然后直接 `send -To test_dispatched`

## 分诊规则（用户规定：确实是 bug 才派修复）

`/code-review` 的审查代理**不了解项目全貌**：它不知道工单范围、协约、契约澄清、实际运行环境（同事的 Windows、Python 版本等）和平台惯例，所以会有误报，也会有"理论上成立、实际不影响"的发现。每一条都要回答下面的问题，结果写进发现清单的"处置"列：

| 判断 | 处置 |
|---|---|
| 能否确认它是真的？在项目**实际环境**下成立吗？ | 不能确认的，先自己验证（复现、读代码、查文档）。仍然验证不了的，**不作为必改项**，写明"未能确认" |
| 真实，并且**违反工单写明的契约**（验收标准、接口约定），或会造成**实际影响**（崩溃、错误结果、数据损坏、安全问题），而且在工单的使用场景里会发生 | **必改 F*n*** |
| 真实，但在本项目的输入范围或使用场景里**实际不会发生、不影响** | **可选**，不派修复，写明理由 |
| 因为**不了解项目**而误判：与协约、工单、平台惯例冲突（例如 Windows 换行、约定俗成的退出码）；要求的是工单"不做"范围内的东西；只是风格偏好 | **不采纳**，写明理由 |
| 性能、重构建议 | 工单有性能验收标准且**未达标**时才必改，否则**可选** |
| 分歧源于工单本身写得不严 | 这是 Claude 的责任：写进"契约澄清"。实现行为合理就不要求改代码 |

最后检查一遍：必改项里的每一条，Claude 都能说清楚"在什么输入、什么环境下，会出什么错"。说不清的，就不应该是必改项。

## B. 状态是 `fix_done`：主 agent 复审（**不要再跑 /code-review**）

1. `scripts/collab.cmd diff -Since reviewed` 查看上次审查之后的改动。
2. **亲自读 diff**，对照上一份 code-review / re-review / report-review 的每个 F / R 编号，逐条判断是否**真正**关闭（看代码，必要时在本机复现验证步骤）。再检查修复有没有引入新问题；新问题同样按上面的分诊规则判断，确实是 bug 才列为 R*n*。
3. `msg -Type re-review -As claude`，逐条写核对结果。
4. 发送：
   - 全部关闭：`send -To test_dispatched`（附测试方案，用 `/collab-testplan`）或 `send -To review_passed`
   - 仍有问题：`send -To rework_requested`（脚本限制最多 2 次；超出时转 `blocked`，用大白话向用户说明情况并给出建议）

## 结束

向用户汇报：结论、`/code-review` 共几条、每种处置各几条、必改项是什么、球现在在谁手里。
