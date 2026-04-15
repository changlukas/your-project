#!/bin/bash
# PreToolUse hook: enforce file edits stay within scope_paths defined in
# .claude/state/phase.json. Opt-in: silently allows everything when state
# file is absent. Use `bash .claude/scripts/scope set <path>...` to enable.
command -v jq >/dev/null 2>&1 || exit 0

STATE=".claude/state/phase.json"
[ -f "$STATE" ] || exit 0  # opt-in: no state, allow all

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
case "$TOOL" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
[ -z "$FILE" ] && exit 0

SCOPE=$(jq -r '.scope_paths[]?' "$STATE" 2>/dev/null | tr -d '\r')
[ -z "$SCOPE" ] && exit 0  # malformed state, allow

# Check if FILE matches any scope path (substring match)
MATCH=0
while IFS= read -r path; do
  path="${path%$'\r'}"  # belt-and-suspenders: strip trailing CR
  [ -z "$path" ] && continue
  case "$FILE" in
    *"$path"*) MATCH=1; break ;;
  esac
done <<< "$SCOPE"

if [ "$MATCH" = "0" ]; then
  SCOPE_LINE=$(echo "$SCOPE" | tr '\n' ' ')
  REASON="File $FILE is outside current task scope. Allowed paths: $SCOPE_LINE. Run 'bash .claude/scripts/scope set <path>' to update, or 'bash .claude/scripts/scope clear' to disable enforcement."
  jq -n --arg r "$REASON" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
fi
exit 0
