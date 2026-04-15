#!/bin/bash
# WorktreeCreate hook: enforce canonical worktree branch naming.
# Accepts:
#   feat/{name}/T00X            — feature task worktree (custom flow)
#   feat/bugfix-{id}/fix        — bugfix workflow worktree (custom)
#   feat/bugfix-{id}/T00X       — bugfix sub-task worktree (custom)
#   feature/*                   — Superpowers vendored using-git-worktrees default
# Blocks: feat/* without sub-pattern (probable typo)
# Ignores: anything else (manual / experimental branches stay free)
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
BRANCH=$(echo "$INPUT" | jq -r '.branch // ""')
[ -z "$BRANCH" ] && exit 0

case "$BRANCH" in
  feat/bugfix-*/fix|feat/bugfix-*/T[0-9]*|feat/*/T[0-9]*|feature/*)
    exit 0  # canonical (custom) or Superpowers-style, allow
    ;;
  feat/*)
    REASON="Worktree branch \"$BRANCH\" starts with feat/ but missing subtask marker. Use feat/{name}/T00X (custom flow), feat/bugfix-{id}/fix (custom bugfix), or feature/{name} (Superpowers default)."
    jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
    exit 0
    ;;
  *)
    exit 0  # not feat/* — let it through
    ;;
esac
