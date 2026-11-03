---
ticket: {{TICKET}}
type: report-review
from: {{FROM}}
date: {{DATE}}
verdict: <accepted | test_rejected | fix_requested>
---

# 测试报告审查 {{TICKET}}

> 规则：COLLABORATION.md §4.8。

## 1. 核对

| 检查项 | 结果 | 说明 |
|---|---|---|
| 命令按方案执行 | ✅/❌ | |
| 计数自洽（汇总 = 逐用例；回归与基线可比） | ✅/❌ | |
| 证据能支撑结论（有原始输出与日志） | ✅/❌ | |
| 无信息基线到位 | ✅/❌ | |
| 变异演示到位（红在指定断言） | ✅/❌ | |
| 回归无新增失败 | ✅/❌ | |

## 2. 结论

### accepted 时填写
- 验证摘要：
- 遗留风险：
- 后续建议：

### test_rejected 时填写（补测项，逐条可验证）
- **T1**

### fix_requested 时填写（产品缺陷即修复项）
- **F<n>** <缺陷，引用报告中的 D-x> —— 验证：<怎么证明修好了>
