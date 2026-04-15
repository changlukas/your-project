#!/bin/bash
# bootstrap.sh — non-interactive scaffold init
# Usage: bash bootstrap.sh
set -euo pipefail

echo "[bootstrap] creating dirs..."
mkdir -p .specify/memory .specify/specs .specify/bugs .claude/logs .claude/agent-memory

echo "[bootstrap] marking hook scripts executable..."
chmod +x .claude/hooks/*.sh 2>/dev/null || true

echo "[bootstrap] checking required tools..."
HAS_JQ=1
command -v jq >/dev/null || { HAS_JQ=0; echo "  WARN: jq not found — hooks expecting jq will no-op"; }
command -v git >/dev/null || { echo "  ERROR: git required"; exit 1; }

echo "[bootstrap] validating settings.json..."
if [ ! -f .claude/settings.json ]; then
  echo "  WARN: .claude/settings.json not found — skipping"
elif [ "$HAS_JQ" = "1" ]; then
  if jq empty .claude/settings.json 2>/dev/null; then
    echo "  OK"
  else
    echo "  WARN: settings.json failed jq validation"
  fi
else
  echo "  SKIP (no jq)"
fi

echo "[bootstrap] done. Next steps:"
echo "  1. Open Claude Code in this dir"
echo "  2. Run /setup for interactive config"
echo "  3. Or edit CLAUDE.md.example -> CLAUDE.md manually"
