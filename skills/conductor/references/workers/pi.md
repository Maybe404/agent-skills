# pi（@earendil-works/pi-coding-agent）

适用版本：pi 1.3.0（每项已标明是否实测）。版本变化后先核对 `pi --help`。

## 适配器速查

| 契约项 | 做法 | 状态 |
|---|---|---|
| 预检 | `scripts/preflight.sh pi <provider/model>` | 已验证 |
| 派发 | `RUN=$(conductor rundir <id>)`；`cd "$DIR" && CONDUCTOR_AUTHOR="<署名>" pi -p --model <provider/model> --session-id <task-id> @"$RUN/brief.md" "按附件中的任务说明执行。" < /dev/null > "$RUN/last.md" 2> "$RUN/err.log"` | 已验证 |
| 拿结果 | text 模式下 stdout 就是最终回复 | 已验证 |
| 成败判断 | 退出码非 0 即失败；json 模式看 `agent_end` 的 `stopReason`/`errorMessage` | 已验证 |
| 续接 | 会话 ID 由你在派发时指定（`--session-id`），续接时复用同一个 ID | 已验证 |
| 权限映射 | 只读 `--tools read,grep,find,ls`；可写为默认工具（read,bash,edit,write）；**没有沙箱**，bash 能碰到整台机器，brief 里必须写明可改路径 | 已验证只读参数存在，未验证限制效果 |
| 选模型 | `--model provider/id[:thinking]`；`--thinking <level>`；`pi --list-models` | 已验证 |
| 审查模式 | 无专门命令；用只读工具集 + 审查 brief | — |
| 写评论 | 默认工具集有 bash，能自己调用 `conductor comment`；只读工具集没有 bash，由编排者原样入档 | 未验证 |
| 坑 | **必须 `< /dev/null`**，否则在 Bash 工具里会无限挂起；默认模型（agent-plan）订阅失效 | 已验证 |

## 详细参考

### 安装与更新

本机是 npm 全局安装（fnm 管理的 Node 下）。更新：`pi update`（更新 pi 和模型目录；扩展需 `pi update --extensions`），只更新本体：`pi update self`。pi 提示 npm 安装不锁依赖，官方推荐迁移到托管安装 `curl -fsSL https://pi.dev/install.sh | sh`——迁移由用户决定。

### 非交互运行：`pi -p`

```bash
pi -p [options] [@files...] "消息"
```

- `-p, --print`：处理完退出。
- `@path`：把文件内容附进消息（brief 用这个传）。
- `--model <pattern>`：`provider/id`，可带思考级别后缀 `provider/id:high`；也支持模糊匹配，但编排时写全名。
- `--provider <name>`：配合 `--model` 限定 provider。
- `--thinking <level>`：off/minimal/low/medium/high/xhigh/max。
- `--mode text|json|rpc`：text 时 stdout 只有最终回复；json 输出事件流。
- `--system-prompt` / `--append-system-prompt <text|file>`：替换/追加系统提示。
- `-nc, --no-context-files`：不加载 AGENTS.md / CLAUDE.md。
- `-a, --approve` / `-na, --no-approve`：信任/忽略项目本地的 `.pi` 文件。在不熟悉的仓库里跑，用 `-na`。
- `--offline`：不做启动时的联网操作。
- 消息以 `-` 开头时，用 `--` 结束选项解析。
- **必须 `< /dev/null`**：stdin 不是终端时 pi 会读 stdin 直到 EOF。在 stdin 永远不结束的环境里（例如某些宿主的命令工具），实测 pi 会无限挂起（无网络连接、无输出）。需要喂 stdin 时用管道或 `< file`。

#### 工具与权限

pi **没有 sandbox**。能力完全由工具集决定：

- 默认：`read, bash, edit, write`（`grep, find, ls` 默认关闭）。
- 只读：`--tools read,grep,find,ls`。
- 增减：`--tools +grep`、`--exclude-tools bash`。
- `-nt` 关掉全部工具，`--no-mcp` 关掉 MCP。

开着 `bash` 就能动整台机器，所以可写任务的 brief 必须写清只能改哪些路径，验收时看 `git status` 是否有范围外改动。

#### 拿结果

- text 模式：stdout 就是最终回复，直接重定向到文件。
- json 模式：最后一条 `agent_end` 事件里有完整 messages、usage、`stopReason`、`errorMessage`。
- 失败退出码为 1（实测：订阅失效时 stopReason 为 error，退出 1）。

#### 会话

- `--session-id <id>`：用你指定的 ID，不存在就新建（会打印一条 Warning，正常）。**编排时首选**：派发时就定好 ID，续接直接复用，不用解析输出。实测同一 ID 第二次调用能记住第一次的内容。
- `-c, --continue`：续接上一个会话（并行时不要用）。
- `--fork <id>`：分叉。
- `--no-session`：不保存。
- `-n, --name`：会话显示名。
- 会话存放：`~/.pi/agent/sessions/`；`--export <session.jsonl>` 导出 HTML。

### 模型配置

目录：`~/.pi/agent/`（`PI_CODING_AGENT_DIR` 可改）。

- `settings.json`：`defaultProvider`、`defaultModel`、`defaultThinkingLevel` 等默认值。
- `models.json`：自定义 provider 和模型（OpenAI 兼容、Anthropic 等端点）。
- `auth.json`：凭据（不要读出或打印）。
- 内置 provider 也可以只靠环境变量鉴权：`ANTHROPIC_API_KEY`、`OPENAI_API_KEY`、`DEEPSEEK_API_KEY`、`OPENROUTER_API_KEY`、`MOONSHOT_API_KEY` 等，完整列表见 `pi --help`。

查看与检查：

```bash
pi --list-models [搜索词]            # 列出可用模型（provider、上下文、是否支持 thinking/图片）
pi auth <command>                    # 检查 provider 就绪状态
pi config                            # TUI，启用/禁用资源（交互式，编排时不用）
```

`--models a,b,c` 只影响交互模式下 Ctrl+P 轮换，非交互不用。
