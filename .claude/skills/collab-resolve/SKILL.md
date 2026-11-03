---
name: collab-resolve
description: 裁决 Codex 发起的质询（query），按证据给出 accept_codex / revise / reject / defer，写 resolution 并把球交回 Codex 或转 blocked。inbox 显示 query 轮到 claude，或用户说"Codex 有疑问"时使用。
---

# 质询裁决（协约 §7）

1. `scripts/collab.cmd open -Ticket T-NNNN -As claude`；读 `query` 消息，以及它指向的原消息条目。STATUS 的 `resume` 是质询前的状态。
2. **核实 Codex 的证据**：亲自看报错、读相关代码、必要时跑命令。按证据裁决，不按身份裁决；Codex 说得对就直接承认。
3. `scripts/collab.cmd msg -Type resolution -As claude`，每条 Q 给出一个决定：
   - `accept_codex` / `revise`：必须写**新的权威指令**，它取代原条目
   - `reject`：说明为什么维持原指令
   - `defer`：写清楚需要人类决定的事
4. 发送：
   - 都有可执行的决定：`send -To <resume 状态> -As claude`（通常就是质询前的状态；指令变化大时可回到 `dispatched`）
   - 含 `defer`：`send -To blocked -As claude`，并用大白话向用户说明：现在怎么做的 → 毛病是什么 → 改了代价是什么
5. 同一问题已经往返 2 轮仍不收敛：转 `blocked`，把双方立场一并交给用户。
6. 裁决涉及受保护路径的改动时，在 resolution 里写明授权值 `Aligned-By: <工单>/<NN-resolution.md>`。
