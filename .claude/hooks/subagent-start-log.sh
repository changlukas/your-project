#!/bin/bash
# SubagentStart hook: log agent_type + agent_id when a subagent starts.
# Event payload schema (per Claude Code docs):
#   { session_id, hook_event_name: "SubagentStart", agent_id, agent_type, ... }
INPUT=$(cat)
AGENT=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')

mkdir -p .claude/logs

jq -n \
  --arg ts "$(date -Iseconds)" \
  --arg event "START" \
  --arg agent "$AGENT" \
  --arg aid "$AGENT_ID" \
  '{timestamp: $ts, event: $event, agent_type: $agent, agent_id: $aid}' \
  >> .claude/logs/agent-activity.jsonl

exit 0
