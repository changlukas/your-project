#!/bin/bash
# UserPromptSubmit hook: route user prompts to the most relevant skill by keyword.
# Optional — silently no-ops if jq missing or rules file absent.
# Outputs hookSpecificOutput.additionalContext when a rule matches.
command -v jq >/dev/null 2>&1 || exit 0
[ -f .claude/skill-rules.json ] || exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')

# Skip very short prompts (chitchat or single-word commands)
MIN=$(jq -r '.min_prompt_chars // 10' .claude/skill-rules.json)
if [ ${#PROMPT} -lt "$MIN" ]; then exit 0; fi

LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Skip if any negative keyword matches (small edits, typos, comments)
NEG=$(jq -r '.negative_keywords[]?' .claude/skill-rules.json)
while IFS= read -r kw; do
  [ -z "$kw" ] && continue
  KWL=$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')
  case "$LOWER" in
    *"$KWL"*) exit 0 ;;
  esac
done <<< "$NEG"

# Match positive rules; output first matching hint
HINT=$(jq -r --arg p "$LOWER" '
  .rules[] | select(
    [ .keywords[] | ascii_downcase ] as $kws |
    any($kws[]; . as $k | $p | contains($k))
  ) | .hint
' .claude/skill-rules.json | head -1)

if [ -n "$HINT" ] && [ "$HINT" != "null" ]; then
  jq -n --arg h "$HINT" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $h
    }
  }'
fi
exit 0
