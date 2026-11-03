# Git 钩子

版本受控的钩子，由 `scripts\collab.cmd setup` 安装（等价于 `git config core.hooksPath scripts/git-hooks`）。
**每台机器 clone 之后都要跑一次 setup。**

## commit-msg

提交涉及**受保护路径**时，提交信息必须带授权 trailer，否则拒绝：

- `Aligned-By: <工单>/<NN-resolution.md>`：基于一次 Claude 对齐裁决
- `Override: <理由>`：用户明确授权

受保护路径与理由见 `COLLABORATION.md` §9。合并提交放行；工单消息目录 `.ai-collab/tickets/` 不受保护。

A 级自治修复（确定性、局部、不改契约）本来就不碰这些路径，所以不受影响。

> 上游模板里的 `post-commit`（`devX.Y` 分支自动打补丁标签）没有沿用：本仓库改为
> "工单分支 + main"模型，版本标签由 Claude 在里程碑时提出、用户确认后再打（协约 §8）。
