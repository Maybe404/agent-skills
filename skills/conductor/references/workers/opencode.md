# opencode

适用版本：opencode 1.19.3（每项已标明是否实测）。版本变化后先核对 `opencode run --help`。

## 适配器速查

| 契约项 | 做法 | 状态 |
|---|---|---|
| 预检 | `scripts/preflight.sh opencode <provider/model>` | 已验证 |
| 派发 | `RUN=$(conductor rundir <id>)`；`CONDUCTOR_AUTHOR="<署名>" opencode run --dir "$DIR" -m <provider/model> --format json -f "$RUN/brief.md" "按附件中的任务说明执行。" < /dev/null > "$RUN/events.jsonl" 2> "$RUN/err.log"` | 未验证完整任务（凭据失效，只用免费模型验证过简单调用） |
| 拿结果 | json 事件流里 `"type":"text"` 事件的 `text` | 已验证 |
| 成败判断 | 退出码非 0 即失败；错误在 `"type":"error"` 事件 | 已验证 |
| 续接 | 会话 ID 取事件流里的 `sessionID`；`opencode run -s <sessionID> "..."` | 已验证 |
| 权限映射 | 只读 `--agent plan`；可写为默认 `build` agent；全权限 `--auto`（危险）。权限由配置决定，非交互下遇到 ask 规则的行为未验证 | 部分验证 |
| 选模型 | `-m provider/model`；`--variant <强度>`；`opencode models` | 已验证 |
| 审查模式 | 无专门命令；用 `--agent plan` + 审查 brief | — |
| 写评论 | `build` agent 能调用 shell，应能自己调用 `conductor comment`；`plan` agent 下由编排者原样入档 | 未验证 |
| 坑 | 默认 provider（opencode-go）key 过期；default 格式输出含 ANSI 转义 | 已验证 |

## 详细参考

### 安装与更新

本机是官方 curl 脚本安装（`~/.opencode/bin/opencode`）。更新：`opencode upgrade`（可指定版本 `opencode upgrade <version>`）。另有 Homebrew 装的 `opencode-desktop` 桌面版，与 CLI 无关，更新用 `brew upgrade --cask opencode-desktop`。

### 非交互运行：`opencode run`

```bash
opencode run [options] "消息"
```

- `--dir <DIR>`：工作目录。
- `-m, --model <provider/model>`：模型。
- `--variant <v>`：provider 相关的推理强度（如 high、max、minimal）。
- `--agent <name>`：用哪个 agent。本机有 `build`（默认，可写）、`plan`（只读规划）；`explore`、`general` 是 subagent。
- `-f, --file <path>`：附文件（brief 用这个传）。
- `--format default|json`：json 输出原始事件流。
- `--title`：会话标题。
- `--pure`：不加载外部插件。
- `--auto`：自动批准所有未被显式拒绝的权限——危险，用户点名才用。
- `--attach <url>`：连到已运行的 `opencode serve`，避免每次冷启动（多次连续派发时可考虑）。

#### 拿结果

- default 格式：stdout 是格式化后的文本回复（实测含 ANSI 转义，存文件后可能需要清理）。
- json 格式：每行一个事件，带 `sessionID`；回复文本在 `"type":"text"` 事件的 `text` 字段，错误在 `"type":"error"` 事件。
- 失败退出码为 1（实测：API key 过期时输出 error 事件并退出 1）。

#### 会话

- 续接：`opencode run -s <sessionID> "..."`（实测有效）。`sessionID` 从 json 事件流第一行取：`grep -o '"sessionID":"[^"]*"' log.jsonl | head -1 | cut -d'"' -f4`。
- `-c, --continue`：续接上一次（并行时不要用）。
- `--fork`：配合 `-c`/`-s` 先分叉。
- 管理：`opencode session`，导出 `opencode export <sessionID>`，用量 `opencode stats`。

### 权限

由配置里的 `permission` 和 agent 定义决定，`opencode agent list` 可看到每个 agent 的权限规则。本机 `build` agent：`*` 全部 allow，`external_directory`（工作目录外的路径）是 ask，`doom_loop` 是 ask。非交互模式下遇到 ask 的行为未实测——需要访问工作目录外时，先小规模试跑确认，不要直接加 `--auto`。

### 模型配置

全局配置：`~/.config/opencode/opencode.json`（或 `.jsonc`）；项目级：仓库根目录的 `opencode.json`。

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "provider/model",          // 默认模型
  "small_model": "provider/model",    // 标题、摘要等轻任务用
  "provider": {
    "myprovider": {
      "npm": "@ai-sdk/openai-compatible",   // 或 @ai-sdk/openai、@ai-sdk/anthropic
      "options": { "baseURL": "https://..." },
      "models": { "model-id": { "name": "显示名" } }
    }
  },
  "agent": {
    "build": { "model": "provider/model" }  // 给特定 agent 指定模型
  }
}
```

- 凭据：`opencode providers`（别名 `opencode auth`）管理，不要读出或打印。
- 列模型：`opencode models [provider]`。
- 一次性换模型：`-m provider/model`。
