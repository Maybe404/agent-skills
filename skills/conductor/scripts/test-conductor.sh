#!/bin/sh
# Tests for scripts/conductor. Usage: test-conductor.sh [shell]  (default: sh)
set -u

SH=${1:-sh}
HERE=$(cd "$(dirname "$0")" && pwd)
C="$SH $HERE/conductor"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$*"; }
check() { # description command...
	d=$1; shift
	if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi
}
has() { # description needle haystack
	case "$3" in *"$2"*) ok ;; *) bad "$1 (missing '$2')"; printf '%s\n' "$3" | sed 's/^/    | /' ;; esac
}
lacks() {
	case "$3" in *"$2"*) bad "$1 (unexpected '$2')"; printf '%s\n' "$3" | sed 's/^/    | /' ;; *) ok ;; esac
}

# --- git repo: init, exclude, idempotence -------------------------------------
R="$TMP/repo"
mkdir -p "$R/sub/dir" && cd "$R" && git init -q
out=$($C init)
has "init prints root" "$R/.conductor" "$out"
check "issues dir created" test -d "$R/.conductor/issues"
check "excluded from git" grep -qx '.conductor/' "$R/.git/info/exclude"
$C init >/dev/null
n=$(grep -cx '.conductor/' "$R/.git/info/exclude")
[ "$n" = 1 ] && ok || bad "init not idempotent ($n exclude lines)"
st=$(git status --porcelain)
lacks "git status ignores .conductor" ".conductor" "$st"

# --- new / list ----------------------------------------------------------------
id1=$($C new -t "Fix login bug" -r mid -l bug -m "plan: reproduce then fix")
[ "$id1" = 0001 ] && ok || bad "first id is 0001 (got $id1)"
printf 'line one\nline two\n' >"$TMP/body.txt"
id2=$($C new -t "Add export" -f "$TMP/body.txt")
[ "$id2" = 0002 ] && ok || bad "second id is 0002 (got $id2)"
id3=$(printf 'from stdin\n' | $C new -t 'Title with \back\slash' -f -)
check "body from stdin" grep -q 'from stdin' "$R/.conductor/issues/$id3/body.md"
has "backslash kept in title" 'Title with \back\slash' "$($C show 3 --last 0)"
out=$($C list)
has "list shows task 1" "#0001  open" "$out"
has "list shows risk" "risk:mid" "$out"
has "list shows labels" "[bug]" "$out"
has "list shows unset risk" "risk:unset" "$out"
check "new without title fails" sh -c "! $C new -m x"
check "new without body fails" sh -c "! $C new -t x </dev/null"
check "bad risk rejected" sh -c "! $C new -t x -r huge -m y"

# --- discovery and id forms --------------------------------------------------
out=$(cd "$R/sub/dir" && $C show '#1' --last 0)
has "found root from subdir; #1 form" "title: Fix login bug" "$out"
out=$(cd "$TMP" && CONDUCTOR_DIR="$R/.conductor" $C show 2 --last 0)
has "CONDUCTOR_DIR override" "title: Add export" "$out"
check "unknown id fails" sh -c "! $C show 99"
check "non-numeric id fails" sh -c "! $C show abc"

# --- comments, authors, verbatim ---------------------------------------------
CONDUCTOR_AUTHOR="实现者 · codex/gpt-6" $C comment 1 -m "fixed in abc123"
$C comment 1 -m "review says ok" --as "审查者 · subagent/sonnet"
printf 'RAW REVIEW OUTPUT\n' >"$TMP/review.md"
$C comment 1 -f "$TMP/review.md" --as "审查者 · codex" --verbatim --posted-by "编排者"
check "verbatim needs posted-by" sh -c "! $C comment 1 -m x --verbatim"
$C comment 2 -m "anonymous"
out=$($C show 1 --all)
has "env author recorded" "author: 实现者 · codex/gpt-6" "$out"
has "--as author recorded" "author: 审查者 · subagent/sonnet" "$out"
has "verbatim kind" "kind: verbatim" "$out"
has "posted-by recorded" "posted-by: 编排者" "$out"
has "verbatim text untouched" "RAW REVIEW OUTPUT" "$out"
has "unknown author default" "author: unknown" "$($C show 2)"
out=$($C show 1 --last 1)
has "--last 1 shows count" "3 total, showing 1" "$out"
lacks "--last 1 hides older" "fixed in abc123" "$out"
has "list counts comments" "(3 comments)" "$($C list)"

# --- status / risk / labels / links / body -----------------------------------
$C status 1 in-progress --as "编排者"
has "status changed" "#0001  in-progress" "$($C list)"
has "status event logged" "status: open -> in-progress" "$($C show 1 --last 1)"
check "bad status rejected" sh -c "! $C status 1 finished"
$C risk 2 high
has "risk changed" "risk:high" "$($C list --status open)"
$C label 1 +needs-review +backend -bug
out=$($C show 1 --last 0)
has "labels added" "needs-review" "$out"
lacks "label removed" "bug" "$(grep '^labels:' "$R/.conductor/issues/0001/meta")"
check "label with comma rejected" sh -c "! $C label 1 +a,b"
$C link 1 branch feat/login
$C link 1 commit abc123
out=$($C show 1 --last 0)
has "link branch" "link.branch: feat/login" "$out"
has "link commit" "link.commit: abc123" "$out"
$C body 1 -m "plan v2: [x] reproduce [ ] fix"
has "body replaced" "plan v2" "$($C show 1 --last 0)"
check "old body kept in history" sh -c "grep -rq 'plan: reproduce then fix' '$R/.conductor/issues/0001/history'"
$C status 2 done
lacks "done hidden from list" "#0002" "$($C list)"
has "done shown with --all" "#0002  done" "$($C list --all)"

# --- config / rundir ---------------------------------------------------------
$C config set workers.implementer "codex"
[ "$($C config get workers.implementer)" = codex ] && ok || bad "config get/set"
$C config set workers.implementer "subagent/sonnet"
[ "$($C config get workers.implementer)" = "subagent/sonnet" ] && ok || bad "config overwrite"
n=$(grep -c '^workers.implementer:' "$R/.conductor/config")
[ "$n" = 1 ] && ok || bad "config key not duplicated ($n)"
rd=$($C rundir 1)
check "rundir created" test -d "$rd"
has "rundir path" ".conductor/runs/0001" "$rd"

# --- concurrency: parallel new and comment ------------------------------------
for i in 1 2 3 4 5 6; do $C new -t "par $i" -m x >"$TMP/par.$i" & done
wait
ids=$(cat "$TMP"/par.* | sort | uniq | wc -l | tr -d ' ')
[ "$ids" = 6 ] && ok || bad "parallel new gave unique ids ($ids/6)"
for i in 1 2 3 4 5 6; do $C comment 3 -m "c$i" --as "w$i" & done
wait
n=$(ls "$R/.conductor/issues/0003/comments" | wc -l | tr -d ' ')
[ "$n" = 6 ] && ok || bad "parallel comments all kept ($n/6)"

# --- no git repo -------------------------------------------------------------
P="$TMP/plain"
mkdir -p "$P" && cd "$P"
out=$($C init)
has "init without git" "$P/.conductor" "$out"
check "new without git" $C new -t plain -m x

# --- usage -------------------------------------------------------------------
check "no args fails" sh -c "! $C"
check "unknown command fails" sh -c "! $C frobnicate"
check "help works" $C --help

printf '%s: %d passed, %d failed\n' "$SH" "$pass" "$fail"
[ "$fail" -eq 0 ]
