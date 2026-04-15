---
name: setup
description: >
  First-run project setup wizard.
  Use when: "setup", "initialize", "configure", "first time",
  or when CLAUDE.md does not exist yet.
disable-model-invocation: true
---

# Project Setup Wizard

你是 Setup Wizard。引導使用者完成新專案的初始設定。
使用 ask_user_question tool 進行互動式提問。
每個步驟完成後確認，再進入下一步。
使用者說「跳過」時，尊重並進入下一步。

---

## Step 1: 專案類型

詢問：「這個專案的主要產出是什麼？」
- **Code**（軟體/硬體實作）→ 之後走 `/brainstorming` → `/writing-plans` → `/executing-plans`（Superpowers flow，ephemeral subagents + TDD Iron Law）
- **Document**（規格文件/專利/技術報告）→ 之後走 `/write-document`（4-phase persistent writer/verifier flow）
- **Both**（混合）→ 兩者皆可用，依任務性質選擇

記住回答，影響後續 agent 配置和總結指引。

同時建立 `.specify/memory/`、`.specify/specs/`、`.specify/bugs/` 目錄（若不存在）。

> **心智模型提醒：** 本 template 採用 ephemeral subagent + skills 模型（見 `docs/design/AGENT_MODEL.md`）。
> Code 專案的 task 執行者是用完即棄的 subagent，不是 persistent named role。

**Gate:** 確認 → 繼續

---

## Step 2: 專案基本資訊 → 生成 CLAUDE.md

詢問：
1. 「這個專案做什麼？一句話描述。」
2. 「使用什麼語言和框架？」
   （如果 codebase 已有檔案，先用 Read/Grep 偵測，向使用者確認）
3. 「你用什麼指令來 build、跑 test、跑 lint？」
   （偵測 package.json / Makefile / Cargo.toml / pyproject.toml 後提議）

根據回答執行 /init 或直接生成 CLAUDE.md。
確認行數 < 80。

**Gate:** 確認 → 繼續

---

## Step 3: Formatter 設定（Code 專案）

如果 Step 1 選了 Code 或 Both：

根據語言提議 formatter：
- JS/TS → prettier
- Python → ruff format
- Go → gofmt
- Rust → rustfmt
- C/C++ → clang-format
- SystemVerilog → verible-verilog-format

確認後編輯 .claude/hooks/auto-format.sh 取消對應註解。
執行 chmod +x。

如果 Step 1 選了 Document：告知 auto-format hook 通常不需要，跳過。

**Gate:** 確認 → 繼續

---

## Step 4: Agent 工具權限

根據專案類型和技術棧，提議 agent tools：

Code 專案 — `task-executor.md`（ephemeral subagent profile，每次 fresh dispatch）:
- Node.js → Bash(npm:*, npx:*, node:*)
- Python → Bash(python:*, pip:*, pytest:*, uv:*)
- Rust → Bash(cargo:*, rustc:*)
- Go → Bash(go:*)
- Make → Bash(make:*)

文件專案 — `writer.md`（persistent agent，跨章節保有語氣與術語記憶）:
- 通常不需要改（Read, Write, Grep, Glob, Bash 已足夠）
- 如果需要跑特定工具（LaTeX, pandoc），加入對應 Bash

`verifier.md` / `code-reviewer.md` 一般不用改。

**Gate:** 確認 → 繼續

---

## Step 5: Skills（可選）

詢問：「你有沒有經常重複給 AI 的指令或規範？
例如 coding style、API 設計規範、文件撰寫格式、專利 claim 結構。
有的話我幫你建成 skill，目前沒有可以之後再加。」

有 → 建立 .claude/skills/<n>/SKILL.md → 使用者 review
沒有 → 跳過

同時提醒跨專案共用 skills 的選項：可放在獨立目錄（例如 `~/shared-skills`），
用 `claude --add-dir ~/shared-skills` 載入，或在 `~/.claude/settings.json`
加入 `additionalDirectories` 永久配置。

**Gate:** 確認 → 繼續

---

## Step 6: MCP（可選）

詢問：「需要連接外部工具嗎？
常見：GitHub、資料庫、Playwright、Jira/Linear。
目前不需要可以之後在 .mcp.json 加。」

有 → 編輯 .mcp.json，提醒 credentials 用環境變數
沒有 → 跳過

**Gate:** 確認 → 繼續

---

## Step 7: Spec Kit + 推薦 Plugins（可選）

### Spec Kit
本 template 目錄結構已對齊 spec-kit 官方慣例（`.specify/memory/`、`.specify/specs/`），可與 specify-cli 共存。

詢問：「要安裝 specify-cli 嗎？本 template 已 vendor Superpowers 的 `/brainstorming`、`/writing-plans`、`/executing-plans` 等 skills，可不裝 CLI 直接用。」
- 要 → `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git && specify init . --ai claude --ai-skills`
- 不要 → 跳過

### Claude Code Plugins（強烈推薦）

詢問：「要安裝以下兩個 plugin 嗎？它們補強我們的 enforcement：
- **tdd-guard**（MIT）— TDD Iron Law 強制，阻擋沒有 failing test 就寫 production code
- **plannotator**（MIT/Apache）— Plan review 視覺 UI

兩者都是 well-maintained Claude Code plugins，非必須但建議裝。」

- 要 →
  ```
  /plugin install tdd-guard
  /plugin marketplace add backnotprop/plannotator
  /plugin install plannotator
  ```
- 不要 → 跳過（之後可隨時 `/plugin install`）

### Pre-commit framework（強烈建議）

詢問：「要啟用 pre-commit framework 嗎？啟用後 commit 時自動驗證 conventional commit 格式 + 跑 gitleaks secret 掃描。」
- 要 → `pipx install pre-commit && pre-commit install`（bootstrap.sh 已嘗試自動安裝）
- 不要 → 跳過

**Gate:** 確認 → 繼續

---

## Step 8: 自訂 Agents（可選）

詢問：「除了預設角色，需要其他角色嗎？
例如 security-auditor、doc-writer、db-specialist。」

有 → 生成 agent definition → 使用者 review
沒有 → 跳過

**Gate:** 確認 → 繼續

---

## Step 9: 總結

展示：

```
=== 設定完成 ===

專案：{name}
類型：{Code / Document / Both}
技術棧：{stack}

✅ CLAUDE.md（{lines} 行）
{✅|⏭️} Formatter（{formatter}）
✅ Agent tools（{agent}: {tools}）
{✅|⏭️} Skills：{count} 個
{✅|⏭️} MCP：{servers}
{✅|⏭️} Spec Kit：{enabled/disabled}
{✅|⏭️} 自訂 Agents：{count} 個

下一步（Code 專案）：
  /brainstorming "功能描述"  → Spec 對話（HARD-GATE，不會未經批准寫 code）
  /writing-plans             → 將 spec 轉為 implementation plan
  /executing-plans              → 逐 task dispatch ephemeral subagent（TDD Iron Law）
  /bugfix "bug 描述"         → Bug 修復 4-phase 流程

下一步（Document 專案）：
  /write-document "文件描述" → 4-phase persistent writer flow

通用：
  直接對話                   → 日常工作
```

提醒 commit：
`git add -A && git commit -m "chore: initialize project configuration"`
