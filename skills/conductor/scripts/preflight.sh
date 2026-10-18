#!/usr/bin/env bash
# Check that a worker CLI + model can answer a trivial prompt right now.
# Usage: preflight.sh <codex|pi|opencode|all> [model]
#   model: codex -> model id; pi/opencode -> provider/model. Omit to use the CLI default.
set -u

worker="${1:-all}"
model="${2:-}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check() {
  local name="$1"; shift
  local out="$tmp/$name.out"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "$name: NOT INSTALLED"; return 1
  fi
  local version; version="$("$name" --version 2>/dev/null | head -1)"
  (cd "$tmp" && "$@") </dev/null >"$out" 2>&1
  local code=$?
  if [ $code -eq 0 ] && grep -q PONG "$out"; then
    echo "$name ($version) ${model:-<default>}: OK"
  else
    echo "$name ($version) ${model:-<default>}: FAIL (exit $code)"
    # Surface the provider's error message without dumping full logs.
    grep -oE '"(message|errorMessage)":"[^"]{0,200}' "$out" | head -2 | sed 's/^/  /'
    tail -3 "$out" | grep -v PONG | cut -c1-200 | sed 's/^/  /'
    return 1
  fi
}

prompt="Reply with exactly: PONG"
rc=0

if [ "$worker" = codex ] || [ "$worker" = all ]; then
  m=(); [ -n "$model" ] && [ "$worker" = codex ] && m=(-m "$model")
  check codex codex exec --skip-git-repo-check --ephemeral -s read-only ${m[@]+"${m[@]}"} "$prompt" || rc=1
fi
if [ "$worker" = pi ] || [ "$worker" = all ]; then
  m=(); [ -n "$model" ] && [ "$worker" = pi ] && m=(--model "$model")
  check pi pi -p --no-session -nt -na ${m[@]+"${m[@]}"} "$prompt" || rc=1
fi
if [ "$worker" = opencode ] || [ "$worker" = all ]; then
  m=(); [ -n "$model" ] && [ "$worker" = opencode ] && m=(-m "$model")
  check opencode opencode run --agent plan ${m[@]+"${m[@]}"} "$prompt" || rc=1
fi

exit $rc
