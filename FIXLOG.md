# FIXLOG — Codex A 级自治修复留痕

Codex 每做一次 **A 级自治修复**（确定性、范围局部、不改任何契约 / 接口 / 测试期望的低级缺陷），
都必须在这里追加一条，作为对 Claude 的**通知与留痕**。Claude 在下一次审查时会读这里。
判定与边界见 `COLLABORATION.md` §6。

- A 级：直接修 → `scripts\collab.cmd fixnote -Summary ... -Why ...` 追加条目 → 单独提交，提交信息以 `[autofix]` 开头。
- B 级：**不许**在这里记一笔了事，必须走质询通道（协约 §7）。

条目由脚本生成，请勿手改历史条目。

---
