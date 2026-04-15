#!/bin/bash
# SubagentStop hook: log agent stop + trigger desktop notification.
# Event payload schema (per Claude Code docs):
#   { session_id, hook_event_name: "SubagentStop", agent_id, agent_type, ... }
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
AGENT=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')

mkdir -p .claude/logs

jq -n \
  --arg ts "$(date -Iseconds)" \
  --arg event "STOP" \
  --arg agent "$AGENT" \
  --arg aid "$AGENT_ID" \
  '{timestamp: $ts, event: $event, agent_type: $agent, agent_id: $aid}' \
  >> .claude/logs/agent-activity.jsonl

# Desktop notification — escape backslashes and double quotes for osascript literal
SAFE_MSG=$(printf '%s' "$AGENT completed" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
osascript -e "display notification \"$SAFE_MSG\" with title \"Claude Code\"" 2>/dev/null
# Linux: notify-send "Claude Code" "$AGENT completed" 2>/dev/null

exit 0
