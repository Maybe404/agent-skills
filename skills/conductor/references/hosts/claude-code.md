# Claude Code

## 1. 向用户提问

用 AskUserQuestion：每题 2–4 个选项，自带"其他"输入框，可多选。首次设置的几个问题合在一次调用里问（最多 4 题）。

## 2. 宿主 subagent

用 Agent 工具派发，它和本会话共享工具环境（文件、Bash、MCP），上下文是全新的。不需要额外凭据，不需要预检。

**派发**
- `prompt` 放 brief 全文，或者让它先读 brief 文件；`model` 选 `opus` / `sonnet` / `haiku`；`subagent_type` 按角色选：
  - 实现者：`general-purpose`
  - 调研者：`Explore`（只读，只要结论）或 `general-purpose`
  - 审查者：`general-purpose`，或直接用内置审查（见第 4 节）
  - 分诊者：`general-purpose` + `haiku`
- 名称后附上模型简称，例如 `审查 auth 改动-Sonnet`。
- 默认在后台运行，完成后会收到通知，最终报告用户看不到，由你转述要点或按原文入档。
- 多个会改文件的 subagent 并行时，加 `isolation: "worktree"`。

**选模型**（用户指定了就按用户的）
- Haiku：分诊、分类、格式转换这类机械判断。
- Sonnet：需要推理和判断的常规任务。
- Opus：深度推理、影响面大、正确性难判断、架构类。只因需要更深的思考才升 Opus，不因为任务重要就升。
- 换模型按 Haiku → Sonnet → Opus 升一档；已经是 Opus 的，按流程退一步重想或交给用户。

**续接**
- 用 SendMessage 发给原 agent（按名称或 ID），上下文保留。这叫 resume，不算新派发。
- 它的上下文超过模型窗口的 40% 就不再续用，改为新开，附上汇总（原目标、已完成的改动、试过又放弃的方案及原因、当前问题、验收标准，路径、名称、数字原样保留）。用量自己算：用 jq 只从它的 transcript 里抽 usage 字段，取最后一条 assistant 记录的 input 加 cache；不读正文，也不问它。

**权限映射**

| 档位 | 做法 |
|---|---|
| 只读 | `Explore` 类型（没有编辑工具），或在 prompt 里写明只读 |
| 工作区可写 | `general-purpose`，prompt 里写明可改的路径；并行时加 `isolation: "worktree"` |
| 全权限 | 与本会话相同，不能再放宽 |

没有独立的沙箱，权限上限就是本会话的权限模式。

**注意**
- 要它验证某个结论时，让它找反例，不找支持证据。
- codegraph 可用时，在 prompt 里注明。
- 写评论：subagent 可以直接调用 `scripts/conductor comment`；派发时在 prompt 里给出完整命令和 `--as "<角色> · subagent/<模型>"`（Agent 工具不能传环境变量）。

## 3. 后台运行

- 外部 CLI：Bash 加 `run_in_background: true`，日志重定向到文件；命令结束时会自动收到通知。不要用 sleep 或循环轮询。
- 需要等待外部状态（例如 CI）时用 Monitor 或 ScheduleWakeup，不要在前台 sleep。

## 4. 内置审查

- `/code-review`：新上下文的子 agent 审当前 diff，可以带 effort 档位和目标（PR 号、分支、路径）。本地运行不读 REVIEW.md。
- `/security-review`：专门审一遍安全问题。

## 5. loop 与定时任务

| 方式 | 适合 | 注意 |
|---|---|---|
| `/loop [间隔] <prompt>`；不给间隔时自定节奏 | 实时盯：issue、PR、聊天频道 | 跑在当前会话里，会话关掉就停 |
| 桌面端的本地定时任务（schedule skill） | 每晚复盘、每日清理这类固定时间的任务 | 在本机跑，能调用本机 CLI worker 和项目文件 |
| `/schedule` 云端定时任务 | 只依赖 GitHub 等在线服务的任务 | 跑在云端，调不到本机 CLI worker 和本地文件，worker 只能用宿主 subagent |

以当前环境实际有的工具为准：先确认工具存在，再告诉用户怎么建。

## 6. 调用参数

用户用 `/conductor <任务>` 调用时，任务描述会附在 skill 内容后面传进来。

## 7. 已知的坑

- macOS 文件系统不区分大小写：名为 `claude.md`、`agents.md` 的文件，会被当成 `CLAUDE.md`、`AGENTS.md` 自动加载成指令。不要用这类文件名。
- Bash 工具的 stdin 是一个永远不会结束的 socket：会读 stdin 的命令（例如 pi）必须加 `< /dev/null`，否则会一直挂住。
