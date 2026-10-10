# agent-skills

集中管理我在用的 agent skills：在 `sources.txt` 里订阅 GitHub 上的 skill，同步到本仓库，再软链接到 `~/.agents/skills` 给各个 agent 使用。

## 目录

```
sources.txt                         订阅列表
sync.sh                             同步与链接脚本
skills/<owner>/<repo>/<skill>/      同步下来的 skill（不要手改，下次同步会被覆盖）
skills/<owner>/<repo>/SOURCE        来源仓库和 commit
skills/<owner>/<repo>/LICENSE       上游许可证
skills/local/<skill>/               不来自任何仓库的 skill（脚本不会动它）
```

## 用法

```bash
./sync.sh update                    # 按 sources.txt 拉取全部
./sync.sh update pbakaus/impeccable # 只更新指定仓库
./sync.sh update --commit           # 拉取后有变化就 commit 并 push（给 VPS 定时任务用）
./sync.sh list                      # 列出 skill 和对应 commit
./sync.sh link --dry-run            # 预览要链接到 ~/.agents/skills 的变动
./sync.sh link                      # 建立软链接；已有的实体目录和外部链接会跳过
./sync.sh link --force              # 实体目录移到 ~/.agents/skills/.backup-<时间>/ 后改为链接
```

链接目标默认 `~/.agents/skills`，可用 `AGENT_SKILLS_TARGET` 修改；链接名取 `SKILL.md` 的 `name` 字段。

## 添加 skill

在 `sources.txt` 加一行 `<owner>/<repo>[@分支] <skill 目录>`，然后执行 `./sync.sh update <owner>/<repo>`。skill 就在仓库根目录时，目录写 `.`。

## 许可证

本仓库公开，同步时会检查许可证：仓库根目录的 LICENSE、skill 目录里的 LICENSE、`SKILL.md` 里的 `license:` 字段，三者都没有就跳过该仓库。自己的仓库（`AGENT_SKILLS_OWNER`，默认 `Maybe404`）不检查。确认可以再分发时，可设 `ALLOW_NO_LICENSE=1` 强制同步。

## VPS 定时更新

```cron
0 4 * * * cd ~/agent-skills && ./sync.sh update --commit >> ~/agent-skills-sync.log 2>&1
```

VPS 上需要有能推送本仓库的 git 凭据（deploy key 或 token）。本机执行 `git pull && ./sync.sh link` 即可拿到更新。
