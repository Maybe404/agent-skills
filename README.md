# agent-skills

My [skilldots](https://github.com/Maybe404/skilldots) library: every skill my agents use, declared in `skills.toml` and linked into `~/.agents/skills` with `skd`.

```
skills.toml      what I subscribe to and which agents get it
skills.lock      pinned upstream commits (written by skd)
skills/          skills I wrote
private/         machine-local skills, a separate git repo that is never pushed
vendor/          third-party skills vendored by skd — do not edit, run `skd fork` instead
```

New machine: `git clone` this repo, then `skd init --from <dir> && skd apply`.
