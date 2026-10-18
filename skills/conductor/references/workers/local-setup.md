# 本机快照（2026-10-18）

会过期。派发前用 `../../scripts/preflight.sh`（skill 根目录下的 `scripts/preflight.sh`）重新确认，结果和这里不一致时以实测为准，并更新本文件。

## 版本

| CLI | 版本 | 安装方式 | 更新命令 |
|---|---|---|---|
| codex | 0.163.0 | 官方 standalone | `codex update` |
| pi | 1.3.0 | npm 全局（fnm Node v24） | `pi update` |
| opencode | 1.19.3 | 官方 curl 脚本 | `opencode upgrade` |

## 默认模型与实测可用性

| CLI | 默认 | 实测 |
|---|---|---|
| codex | provider `custom`（heiyucode 端点）/ `gpt-6-astra`，reasoning high | 可用 |
| pi | `agent-plan/ark-code-latest`，thinking high | 默认不可用：火山方舟 AgentPlan 订阅失效（InvalidSubscription）。`heiyucode/gpt-5.6-terra` 可用 |
| opencode | 未在配置里设默认，`plan` agent 实际用 `glm-5.3`（opencode-go） | 默认不可用：OpenCode Go 的 API key 过期；`heiyucode/gpt-5.5` 报无效 API Key；`opencode/big-pickle`（免费）可用 |

结论（问用户选 worker 时，把这个可用性一起告诉用户）：codex 默认配置可用；pi 需要 `--model heiyucode/...` 才能跑；opencode 只有免费模型可用。宿主 subagent 不需要预检。

## 已配置的 provider

- codex：`~/.codex/config.toml` 主配置；profile `arkcli`（火山方舟 deepseek-v4-1-flash，带搜索 MCP 和 hooks）、`seedmux`，用 `-p <name>` 叠加。
- pi（`pi --list-models`）：agent-plan、volcengine（DeepSeek v4、豆包 seed 2.x）、heiyucode（gpt-5.6-sol/terra、gpt-6-astra）、xai（grok-4.3~4.7）、cmkey（kimi-k3）、syncotech（qwen3-27b）。
- opencode（`opencode models`）：opencode / opencode-go 内置目录，自定义 heiyucode、heiyucode-grok、heiyuzhonglv、lm（本地 LM Studio）、one。
