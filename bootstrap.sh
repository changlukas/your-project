#!/bin/bash
# bootstrap.sh — non-interactive scaffold init
# Usage: bash bootstrap.sh
set -euo pipefail

OK_JQ=0; OK_PRECOMMIT=0; OK_SETTINGS=0

echo "[bootstrap] creating dirs..."
mkdir -p .specify/memory .specify/specs .specify/bugs .claude/logs .claude/agent-memory .claude/state

echo "[bootstrap] marking hook scripts executable..."
chmod +x .claude/hooks/*.sh 2>/dev/null || true
chmod +x .claude/scripts/* 2>/dev/null || true

echo "[bootstrap] checking required tools..."
command -v git >/dev/null || { echo "  ERROR: git required"; exit 1; }
echo "  OK: git present"

if command -v jq >/dev/null 2>&1; then
  OK_JQ=1
  echo "  OK: jq present"
else
  echo "  ERROR: jq required by hooks. Install:"
  echo "    macOS:   brew install jq"
  echo "    Linux:   apt-get install jq  (or: yum install jq)"
  echo "    Windows: scoop install jq    (or: choco install jq)"
  echo "  Hooks will silently no-op without jq. Aborting bootstrap."
  exit 1
fi

echo "[bootstrap] validating settings.json..."
if [ -f .claude/settings.json ] && jq empty .claude/settings.json 2>/dev/null; then
  OK_SETTINGS=1
  echo "  OK"
else
  echo "  WARN: settings.json missing or invalid"
fi

echo "[bootstrap] checking pre-commit framework..."
if command -v pre-commit >/dev/null 2>&1; then
  pre-commit install --install-hooks 2>&1 | sed 's/^/  /' || true
  OK_PRECOMMIT=1
  echo "  OK: pre-commit hooks installed"
else
  echo "  WARN: pre-commit not installed (commit message + secret scanning will not enforce)"
  echo "    install: pipx install pre-commit  (or: pip install --user pre-commit)"
  echo "    then:    pre-commit install"
fi

echo
echo "=== bootstrap summary ==="
echo "  ✓ git"
[ "$OK_JQ" = "1" ]        && echo "  ✓ jq"          || echo "  ✗ jq"
[ "$OK_SETTINGS" = "1" ]  && echo "  ✓ settings"    || echo "  ✗ settings"
[ "$OK_PRECOMMIT" = "1" ] && echo "  ✓ pre-commit"  || echo "  ⏭ pre-commit (optional)"
echo

if [ "$OK_JQ" = "1" ] && [ "$OK_SETTINGS" = "1" ]; then
  echo "Status: READY"
  echo "Next: claude  →  /setup  (interactive setup wizard)"
else
  echo "Status: INCOMPLETE — fix above issues before using"
  exit 1
fi
