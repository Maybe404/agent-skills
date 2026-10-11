#!/usr/bin/env bash
# Sync vendored agent skills and link them into the agents skills directory.
#
#   ./sync.sh update [--commit] [owner/repo ...]   fetch sources.txt into skills/
#   ./sync.sh link   [--dry-run] [--force]         symlink skills/ into $AGENT_SKILLS_TARGET
#   ./sync.sh list                                 show synced skills and their commits
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES="$ROOT/sources.txt"
SKILLS="$ROOT/skills"
TARGET="${AGENT_SKILLS_TARGET:-$HOME/.agents/skills}"
OWNER="${AGENT_SKILLS_OWNER:-Maybe404}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log()  { printf '%s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }

# Print "repo<TAB>path" lines from sources.txt, sorted by repo.
read_sources() {
  sed -e 's/#.*//' "$SOURCES" | awk 'NF >= 2 { print $1 "\t" $2 }' | sort -u
}

# Read the `name:` field from a SKILL.md frontmatter; fall back to the dir name.
skill_name() {
  local dir="$1" name
  name="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
               NR>1 && /^name:/ {sub(/^name:[ \t]*/, ""); gsub(/["\047]/, ""); print; exit}' \
          "$dir/SKILL.md")"
  printf '%s' "${name:-$(basename "$dir")}"
}

find_license() {
  local f
  for f in "$1"/LICENSE* "$1"/LICENCE* "$1"/COPYING*; do
    [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

has_license_field() {
  awk 'NR==1 && $0!="---" {exit 1} NR>1 && $0=="---" {exit 1} NR>1 && /^license:[ \t]*[^ \t]/ {exit 0}' \
    "$1/SKILL.md"
}

# Fetch one repo and rebuild skills/<owner>/<repo>/ from the given paths.
sync_repo() {
  local spec="$1"; shift
  local repo="${spec%@*}" ref="" tmp clone stage group sha license p src dest
  [[ "$spec" == *@* ]] && ref="${spec#*@}"
  [[ "$repo" == */* ]] || { warn "$spec: 不是 owner/repo 格式，跳过"; return 1; }

  tmp="$(mktemp -d "$WORK/repo.XXXXXX")"
  clone="$tmp/repo"; stage="$tmp/stage"

  log "→ $spec"
  if ! git clone -q --depth 1 ${ref:+--branch "$ref"} "https://github.com/$repo.git" "$clone"; then
    warn "$spec: 克隆失败，保留旧版本"; return 1
  fi
  sha="$(git -C "$clone" rev-parse HEAD)"

  license="$(find_license "$clone" || true)"

  mkdir -p "$stage"
  for p in "$@"; do
    src="$clone/${p%/}"
    [[ -f "$src/SKILL.md" ]] || { warn "$spec: $p 下没有 SKILL.md，整组保留旧版本"; return 1; }
    # Republishing needs a license: repo root, skill dir, or SKILL.md `license:` field.
    # Our own repos (owner == $OWNER) are exempt.
    if [[ -z "$license" && "${repo%%/*}" != "$OWNER" && "${ALLOW_NO_LICENSE:-0}" != 1 ]] \
       && ! find_license "$src" >/dev/null && ! has_license_field "$src"; then
      warn "$spec: $p 找不到许可证，整组跳过（确认可再分发后设 ALLOW_NO_LICENSE=1）"
      return 1
    fi
    if [[ "$p" == "." ]]; then dest="$stage/${repo#*/}"; else dest="$stage/$(basename "$p")"; fi
    rsync -a --delete --exclude .git "$src/" "$dest/"
  done
  [[ -n "$license" ]] && cp "$license" "$stage/$(basename "$license")"
  printf 'repo: %s\nref: %s\ncommit: %s\n' "$repo" "${ref:-HEAD}" "$sha" > "$stage/SOURCE"

  group="$SKILLS/$repo"
  mkdir -p "$(dirname "$group")"
  rm -rf "$group"
  mv "$stage" "$group"
  log "  ✓ ${sha:0:7}  $*"
}

cmd_update() {
  local commit=0 only=() line repo path cur="" paths=() failed=0 wanted=()
  while (($#)); do
    case "$1" in
      --commit) commit=1 ;;
      -*) die "未知参数 $1" ;;
      *) only+=("$1") ;;
    esac
    shift
  done

  matches() {
    ((${#only[@]} == 0)) && return 0
    local o; for o in "${only[@]}"; do [[ "$1" == "$o" || "${1%@*}" == "$o" ]] && return 0; done
    return 1
  }
  flush() {
    [[ -n "$cur" ]] || return 0
    matches "$cur" && { sync_repo "$cur" "${paths[@]}" || failed=$((failed + 1)); }
    return 0
  }

  while IFS=$'\t' read -r repo path; do
    wanted+=("${repo%@*}")
    if [[ "$repo" != "$cur" ]]; then flush; cur="$repo"; paths=(); fi
    paths+=("$path")
  done < <(read_sources)
  flush

  # Drop groups no longer listed in sources.txt (full runs only; skills/local and skills/private are never touched).
  if ((${#only[@]} == 0)) && [[ -d "$SKILLS" ]]; then
    local g rel w keep
    for g in "$SKILLS"/*/*/; do
      [[ -d "$g" ]] || continue
      rel="${g#"$SKILLS"/}"; rel="${rel%/}"
      [[ "$rel" == local/* || "$rel" == private/* ]] && continue
      keep=0; for w in "${wanted[@]}"; do [[ "$w" == "$rel" ]] && keep=1 && break; done
      ((keep)) || { log "✗ 移除 $rel（已不在 sources.txt）"; rm -rf "$g"; }
    done
    find "$SKILLS" -mindepth 1 -maxdepth 1 -type d -empty -delete
  fi

  if ((commit)); then
    git -C "$ROOT" add -A skills
    if git -C "$ROOT" diff --cached --quiet; then
      log "没有变化"
    else
      git -C "$ROOT" commit -qm "chore(skills): sync vendored skills" \
        -m "$(git -C "$ROOT" diff --cached --name-only | awk -F/ '{print $2 "/" $3}' | sort -u)"
      git -C "$ROOT" push -q
      log "已提交并推送"
    fi
  fi

  ((failed == 0)) || die "$failed 个仓库同步失败，见上方提示"
}

# List every skill dir: "name<TAB>path".
collect_skills() {
  local f d
  for f in "$SKILLS"/*/*/*/SKILL.md "$SKILLS"/local/*/SKILL.md "$SKILLS"/private/*/SKILL.md; do
    [[ -f "$f" ]] || continue
    d="$(dirname "$f")"
    printf '%s\t%s\n' "$(skill_name "$d")" "$d"
  done | sort -u
}

cmd_link() {
  local dry=0 force=0 name src dst cur dup backup=""
  while (($#)); do
    case "$1" in
      --dry-run|-n) dry=1 ;;
      --force) force=1 ;;
      *) die "未知参数 $1" ;;
    esac
    shift
  done
  run() { if ((dry)); then log "  [dry-run] $*"; else "$@"; fi; }

  dup="$(collect_skills | cut -f1 | uniq -d)"
  [[ -z "$dup" ]] || die "skill 重名，先在 sources.txt 里去掉其中一个：$dup"

  log "目标目录：$TARGET"
  ((dry)) || mkdir -p "$TARGET"

  while IFS=$'\t' read -r name src; do
    dst="$TARGET/$name"
    if [[ -L "$dst" ]]; then
      cur="$(readlink "$dst")"
      [[ "$cur" == "$src" ]] && continue
      if [[ "$cur" != "$SKILLS"/* ]] && ((!force)); then
        warn "$name: 已链接到 $cur，跳过（--force 覆盖）"; continue
      fi
      log "↻ $name"; run ln -sfn "$src" "$dst"
    elif [[ -e "$dst" ]]; then
      if ((!force)); then warn "$name: 已存在实体目录，跳过（--force 会移到备份目录）"; continue; fi
      backup="${backup:-$TARGET/.backup-$(date +%Y%m%d%H%M%S)}"
      log "⇢ $name 移到 $backup"; run mkdir -p "$backup"; run mv "$dst" "$backup/"
      run ln -s "$src" "$dst"
    else
      log "+ $name"; run ln -s "$src" "$dst"
    fi
  done < <(collect_skills)

  # Remove links that point into this repo but whose skill is gone.
  for dst in "$TARGET"/*; do
    [[ -L "$dst" ]] || continue
    cur="$(readlink "$dst")"
    [[ "$cur" == "$SKILLS"/* && ! -e "$cur" ]] && { log "- $(basename "$dst")"; run rm "$dst"; }
  done
  return 0
}

cmd_list() {
  local name src commit
  while IFS=$'\t' read -r name src; do
    case "$src" in
      "$SKILLS"/private/*) commit=private ;;
      "$SKILLS"/local/*) commit=local ;;
      *) commit="$(awk '/^commit:/ {print substr($2,1,7)}' "$(dirname "$src")/SOURCE" 2>/dev/null || true)" ;;
    esac
    printf '%-28s %-8s %s\n' "$name" "$commit" "${src#"$ROOT"/}"
  done < <(collect_skills)
}

case "${1:-}" in
  update) shift; cmd_update "$@" ;;
  link)   shift; cmd_link "$@" ;;
  list)   shift; cmd_list ;;
  *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
