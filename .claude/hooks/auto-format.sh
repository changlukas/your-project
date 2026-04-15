#!/bin/bash
# PostToolUse hook: auto-format after every Edit
# Uncomment the line matching your language.
# Document projects usually don't need this.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE" ]; then
  exit 0
fi

# JavaScript / TypeScript
# npx prettier --write "$FILE" 2>/dev/null

# Python
# ruff format "$FILE" 2>/dev/null

# Go
# gofmt -w "$FILE" 2>/dev/null

# Rust
# rustfmt "$FILE" 2>/dev/null

# C / C++
# clang-format -i "$FILE" 2>/dev/null

# SystemVerilog
# verible-verilog-format --inplace "$FILE" 2>/dev/null

exit 0
