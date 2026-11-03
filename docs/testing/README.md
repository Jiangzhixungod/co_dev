# 测试证据

每张工单一个子目录：`docs/testing/<工单目录名>/`，例如 `docs/testing/T-0001-skeleton/`。

放什么：

- 各层测试的**完整原始日志**（`unit.log`、`integration.log`、`regression.log`）
- main 基线结果（`baseline.log`）
- 变异演示日志（`mutation-M-1.log`……）

测试报告（工单目录下的 `NN-test-report.md`）只放摘录，并指向这里的完整日志。
**只放实测产物**，不放手写的"预期结果"。
