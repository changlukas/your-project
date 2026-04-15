#!/bin/bash
# Notification hook: triggered when Claude needs attention (e.g., permission prompt)
INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.message // "Claude needs your attention"')

# Escape backslashes and double quotes for osascript string literal
SAFE_MSG=$(printf '%s' "$MESSAGE" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

# macOS
osascript -e "display notification \"$SAFE_MSG\" with title \"Claude Code\"" 2>/dev/null

# Linux (requires libnotify)
# notify-send "Claude Code" "$MESSAGE" 2>/dev/null

# Always log — works on any platform, useful for Windows where no built-in notification
mkdir -p .claude/logs
echo "[$(date -Iseconds)] NOTIFY: $MESSAGE" >> .claude/logs/notifications.log

exit 0
