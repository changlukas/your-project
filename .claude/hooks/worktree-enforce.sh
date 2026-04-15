#!/bin/bash
# WorktreeCreate hook: enforce canonical worktree branch naming.
# Accepts three patterns used by orchestrate / bugfix flows:
#   feat/{name}/T00X            — feature task worktree
#   feat/bugfix-{id}/fix        — bugfix workflow worktree
#   feat/bugfix-{id}/T00X       — bugfix sub-task worktree
# Other prefixes (e.g., experiment/foo) are ignored — only branches starting
# with "feat/" but failing sub-pattern get blocked.
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
BRANCH=$(echo "$INPUT" | jq -r '.branch // ""')
[ -z "$BRANCH" ] && exit 0

case "$BRANCH" in
  feat/bugfix-*/fix|feat/bugfix-*/T[0-9]*|feat/*/T[0-9]*)
    exit 0  # canonical, allow
    ;;
  feat/*)
    REASON="Worktree branch \"$BRANCH\" starts with feat/ but does not match canonical sub-patterns: feat/{name}/T00X, feat/bugfix-{id}/fix, or feat/bugfix-{id}/T00X."
    jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
    exit 0
    ;;
  *)
    exit 0  # not feat/* — let it through
    ;;
esac
