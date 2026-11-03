---
name: collab-accept
description: 审查 Codex 的测试报告并做出验收结论（accepted / test_rejected / fix_requested），以及在用户确认后合并已验收的工单。test_done 或 accepted 轮到 claude、用户说"测试做完了""验收""合并"时使用。
---

# 报告审查、验收与合并（协约 §4.8、§4.9）

## A. 状态是 `test_done`：审查测试报告

1. `scripts/collab.cmd open -Ticket T-NNNN -As claude`；对照最近一份 `test-plan` 读 `test-report`，并打开 `docs/testing/<工单>/` 里的完整日志抽查。
2. 逐项核对（写进 `report-review` 的核对表）：
   - 命令是否按方案执行；被测提交是否等于 STATUS 里的 `code_head`
   - 计数是否自洽：汇总等于逐用例；回归与 main 基线可比
   - 每个结论都有原始输出支撑；没有"应该通过"之类的推测
   - 无信息基线到位；变异演示**红在指定断言上**（看失败信息，不只看退出码）
   - 全量回归无新增失败，跳过数没有无故增加
3. `scripts/collab.cmd msg -Type report-review -As claude`，然后三选一：
   - 证据不足或漏测：`send -To test_rejected`（列出补测项 T1…）
   - 测出产品缺陷：`send -To fix_requested`（缺陷即修复项 F…；修复后走主 agent 复审，再重跑回归）
   - 全部满足：`send -To accepted`（写验证摘要、遗留风险、后续建议）

## B. 状态是 `accepted`：合并

1. 预览（不改任何东西）：`scripts/collab.cmd merge -Ticket T-NNNN`
2. 把预览结果（提交列表、改动统计）和验收结论**交给用户，请用户确认**。
3. 用户确认后：`scripts/collab.cmd merge -Ticket T-NNNN -Push`
4. 在 `docs/plan/tracker.md` 勾掉该项；到了里程碑时，向用户提议 SemVer 标签（不要自己打）。
