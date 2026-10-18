# codex（OpenAI Codex CLI）

适用版本：codex-cli 0.163.0（每项已标明是否实测）。版本变化后先核对 `codex exec --help`。

## 适配器速查

| 契约项 | 做法 | 状态 |
|---|---|---|
| 预检 | `scripts/preflight.sh codex [model]` | 已验证 |
| 派发 | `RUN=$(conductor rundir <id>)`；`CONDUCTOR_AUTHOR="<署名>" codex exec -C "$DIR" -s <档位> [-m <model>] --json -o "$RUN/last.md" - < "$RUN/brief.md" > "$RUN/events.jsonl" 2> "$RUN/err.log"`（brief 从 stdin 读） | 已验证 |
| 拿结果 | `-o` 指定的文件；事件流里 `agent_message` | 已验证 |
| 成败判断 | 退出码非 0 即失败；错误在 stderr | 已验证 |
| 续接 | 会话 ID 取事件流 `thread.started` 的 `thread_id`；`codex exec resume <thread_id> "..."` | 已验证（`--last` 形式） |
| 权限映射 | 只读 `-s read-only`；可写 `-s workspace-write`；全权限 `-s danger-full-access`。有真正的沙箱。本机全局默认是全权限，**必须显式传 `-s`** | 已验证 |
| 选模型 | `-m <model>`；`-c model_reasoning_effort="xhigh"`；换整套 provider 用 `-p <profile>` | 已验证 `-m` |
| 审查模式 | `codex exec -C "$DIR" -s read-only review --uncommitted \| --base <branch> \| --commit <sha> -o "$RUN/review.md"` | 已验证 `--uncommitted` |
| 写评论 | `workspace-write` 档位下能自己调用 `conductor comment`，`CONDUCTOR_AUTHOR` 会传进去；`read-only` 档位写不了文件，由编排者原样入档 | 已验证 workspace-write |
| 坑 | stderr 反复打印 refresh token 失效，不影响自定义 provider；全局 `notify` 钩子每轮都会触发 | 已验证 |

## 详细参考

### 安装与更新

官方 standalone 安装（二进制在 `~/.codex/packages/standalone/`，`~/.local/bin/codex` 是软链）。更新：`codex update`。诊断：`codex doctor`。

### 非交互运行：`codex exec`

```bash
codex exec [OPTIONS] [PROMPT]
```

- prompt 不给或给 `-`：从 stdin 读。给了 prompt 又有 stdin 管道：stdin 作为 `<stdin>` 块追加。长 brief 用 `- < brief.md`。
- `-C, --cd <DIR>`：工作根目录。
- `--skip-git-repo-check`：允许在非 git 目录运行（默认要求 git 仓库）。
- `-m, --model <MODEL>`：模型。
- `-p, --profile <NAME>`：叠加 `$CODEX_HOME/<NAME>.config.toml`（换整套 provider + 模型 + MCP 时用）。
- `-c key=value`：临时覆盖任意配置项，值按 TOML 解析，例：`-c model_reasoning_effort="xhigh"`。
- `-s, --sandbox`：`read-only` / `workspace-write` / `danger-full-access`。**总是显式传。**
- `--add-dir <DIR>`：额外可写目录。
- `--worktree`：在新的托管 git worktree 里跑。
- `--search`：开启联网搜索。
- `-i, --image <FILE>`：附图。
- `--ephemeral`：不落盘会话（之后无法续接）。
- `--ignore-user-config`：不读 `~/.codex/config.toml`（鉴权仍用 `CODEX_HOME`）。

#### 拿结果

- `-o, --output-last-message <FILE>`：最终回复写入文件——编排时首选。
- `--json`：stdout 输出 JSONL 事件。关键事件：
  - `{"type":"thread.started","thread_id":"..."}` → 续接用的 ID
  - `{"type":"item.completed","item":{"type":"agent_message","text":"..."}}` → 回复
  - `{"type":"turn.completed","usage":{...}}` → token 用量
- `--output-schema <FILE>`：给 JSON Schema，约束最终回复的结构（需要机器可读的验收报告时用）。
- 日志/错误写 stderr。退出码非 0 即失败。

#### 续接与分叉

```bash
codex exec resume <thread_id> "后续指令"
codex exec resume --last "后续指令"     # 最近一次；并行时不要用 --last，会拿错会话
codex exec fork <thread_id> "..."        # 从某会话分叉出新会话
```

#### 代码审查

```bash
codex exec -C <dir> -s read-only review --uncommitted -o review.md   # 审查暂存、未暂存和未跟踪的改动
codex exec review --base main                                         # 审查相对 main 分支的改动
codex exec review --commit <sha>                                      # 只审某个提交引入的改动（增量复审用）
codex exec review --uncommitted "重点检查并发和错误处理"              # 追加审查要求；给 - 则从 stdin 读
```

支持 `-o`、`--json`、`--title`。

### 模型配置

配置文件：`~/.codex/config.toml`（`CODEX_HOME` 可改目录）。

```toml
model = "gpt-6-astra"
model_provider = "custom"
model_reasoning_effort = "high"      # minimal/low/medium/high/xhigh
sandbox_mode = "workspace-write"
approval_policy = "on-request"       # 或 never

[model_providers.custom]
name = "custom"
base_url = "https://..."
wire_api = "responses"               # 或 chat
requires_openai_auth = false
env_key = "CUSTOM_API_KEY"           # 从环境变量取 key
```

- 一次性换模型：`-m <model>`；换推理强度：`-c model_reasoning_effort="xhigh"`。
- 换整套 provider：写一个 `~/.codex/<name>.config.toml`，用 `-p <name>` 叠加。
- 本地模型：`--oss --local-provider ollama|lmstudio`。
- 登录：`codex login` / `codex logout`。

### 注意

- 本机全局默认是 `approval_policy = "never"` + `sandbox_mode = "danger-full-access"`。
- 实测 stderr 会反复打印 `Failed to refresh token ... refresh token was revoked`，但走的是自定义 provider，不影响运行；判断成败看退出码和 `agent_message`，不要被这条日志误导。如需消除，由用户自己 `codex logout` 后重新处理登录。
- 全局配置里有 `notify` 钩子，每轮结束会调用外部程序；需要完全干净的运行时可加 `--ignore-user-config` 并显式传 `-m` 和 provider 配置。
