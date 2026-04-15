#!/bin/bash
# Stop hook: run full verification after Claude finishes responding.
# Only runs when there are file changes, to avoid triggering on Q&A sessions.

# Handle fresh repo (no HEAD yet): compare against empty tree.
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  CHANGED=$(git diff --name-only HEAD 2>/dev/null | head -20)
else
  CHANGED=$(git diff --cached --name-only 2>/dev/null | head -20)
fi

if [ -z "$CHANGED" ]; then
  exit 0
fi

echo "=== Post-response verification ==="

# Python 專案
# echo "--- ruff check ---"
# ruff check . 2>&1 | tail -20
# echo "--- mypy ---"
# mypy . 2>&1 | tail -20

# TypeScript 專案
# echo "--- tsc ---"
# npx tsc --noEmit 2>&1 | tail -20
# echo "--- eslint ---"
# npx eslint . 2>&1 | tail -20

# Go 專案
# echo "--- go vet ---"
# go vet ./... 2>&1 | tail -20

# SystemVerilog 專案
# echo "--- verilator lint ---"
# verilator --lint-only *.sv 2>&1 | tail -20

exit 0
