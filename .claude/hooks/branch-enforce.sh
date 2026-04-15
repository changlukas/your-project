#!/bin/bash
# PreToolUse hook: enforce that file edits only happen on allowed branches.
# Allowed: feat/*, chore/*, docs/*, bugfix/*
# Denied:  main, master, anything else
# Outputs hookSpecificOutput.permissionDecision when denying.
command -v jq >/dev/null 2>&1 || exit 0

BRANCH=$(git branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && exit 0  # not in a git repo, allow

case "$BRANCH" in
  main|master)
    REASON="Cannot edit on \"$BRANCH\". Create a feat/{name} (or chore/*, docs/*, bugfix/*) branch first."
    ;;
  feat/*|chore/*|docs/*|bugfix/*)
    exit 0  # allow
    ;;
  *)
    REASON="Branch \"$BRANCH\" is not allowed for edits. Use feat/*, chore/*, docs/*, or bugfix/* prefix. Create with: git switch -c feat/your-name"
    ;;
esac

jq -n --arg r "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
