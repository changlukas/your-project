# USAGE — 使用流程逐 stage 對照

這份文件帶你逐 stage 對照本 template 的 AI workflow：在每個情境下你打什麼、AI 自動做什麼、
你需要在哪些地方點頭。讀過一次大概就知道日常怎麼用。

> 心智模型前置：本 template 採用 ephemeral subagent + skills 模型（task 執行者用完即棄）。
> 詳細論證見父層 `docs/design/AGENT_MODEL.md`。

---

## TL;DR — 三秒鐘決策樹

| 你想做什麼？ | 怎麼開始 | 流程強度 |
|---|---|---|
| 新功能（feature） | 直接描述需求即可，AI 會引導你進入 `/brainstorming` | **重**：spec → plan → tasks → TDD subagent execution → review |
| 修 bug | 直接描述 bug 即可，AI 會引導你進入 `/bugfix` | **中**：report → analyze → TDD fix → verify |
| 寫文件 / 專利 / 報告 | 直接描述文件需求，AI 會引導你進入 `/write-document` | **中**：spec → structure → chapter tasks → verify → review |
| 改 typo / comment / rename / 小修 | 直接告訴 AI 改什麼 | **無**：跳過所有流程，但 branch 仍須是 feat/chore/docs/bugfix |
| 問問題 / 看 code | 直接問 | **無**：純對話，不觸發任何流程 |

---

## 入口指令速查

| 指令 | 用途 | 由誰觸發 |
|---|---|---|
| `bash bootstrap.sh` | 非互動式環境初始化 | 第一次 clone template 後跑一次 |
| `/setup` | 互動式設定 wizard | 第一次進 Claude Code 時 |
| `/brainstorming` | Spec 階段對話（HARD-GATE design before code） | 描述新功能後，AI 會主動建議 |
| `/writing-plans` | 把 spec 轉成 implementation plan | spec approved 後 |
| `/executing-plans` | 逐 task dispatch ephemeral subagent | plan approved 後 |
| `/bugfix` | 4-phase bug 修復流程 | 描述 bug 後，AI 會主動建議 |
| `/write-document` | 文件專案 4-phase 流程 | 描述文件需求後，AI 會主動建議 |
| `bash .claude/scripts/scope set <path>...` | **opt-in** 啟用 scope enforcement | 你想限制 task 只能改某些目錄時 |
| `bash .claude/scripts/scope clear` | 解除 scope enforcement | 不需要時 |
| `bash .claude/scripts/scope show` | 顯示當前 scope 狀態 | 任何時候 |

---

## Stage 0: 第一次拿到 template

### 你打什麼

```bash
gh repo create my-project --template changlukas/your-project --clone
cd my-project
bash bootstrap.sh
```

### 自動發生

`bootstrap.sh` 依序檢查並建立：
1. 建立 `.specify/{memory,specs,bugs}`、`.claude/{logs,agent-memory,state}` 目錄
2. 把 `.claude/hooks/*.sh` 和 `.claude/scripts/scope` 標記 executable
3. **檢查 `git`**（必須）→ ✓ 或 ERROR exit
4. **檢查 `jq`**（必須，hooks 硬相依）→ ✓ 或 ERROR + 安裝指引 + exit 1
5. 驗證 `.claude/settings.json` 是合法 JSON
6. **嘗試裝 pre-commit framework**（可選，commit 時的 conventional commit + gitleaks）→ ✓ 或 WARN
7. 印出 summary block：

```
=== bootstrap summary ===
  ✓ git
  ✓ jq
  ✓ settings
  ✓ pre-commit       (or ⏭ if skipped)

Status: READY
Next: claude  →  /setup
```

### 你需要做什麼

- 看到 `Status: READY` → 進下一步
- 看到 `Status: INCOMPLETE` → 按提示裝缺失的工具（通常是 jq）
- pre-commit 是 ⏭（可選），不影響繼續

### 然後

```bash
claude
> /setup
```

進入 Stage 0.5 互動式 wizard。

---

## Stage 0.5: `/setup` 互動式設定

### 自動發生

`setup` skill 啟動，跑 9 步問你：
1. **專案類型**：Code / Document / Both → 影響後續引導
2. **CLAUDE.md 內容**：技術棧、build/test/lint 指令 → 寫入 CLAUDE.md
3. **Formatter**（Code 專案）：選語言 → 取消 `.claude/hooks/auto-format.sh` 對應行的註解
4. **Agent 工具權限**：`task-executor.md` 的 `tools` 是否要加 `Bash(npm:*)` 等
5. **Skills**（可選）：你想加自訂 skill 嗎
6. **MCP**（可選）：要連 GitHub / DB / Playwright 等
7. **Spec Kit + 推薦 plugins**：是否裝 specify-cli、tdd-guard、plannotator、pre-commit
8. **自訂 agents**（可選）
9. **總結 + 下一步指令**

### 你需要做什麼

- 每一步答 / 跳過
- 結束時看到下一步指令清單，記住 `/brainstorming`、`/bugfix`、`/write-document` 三個入口

### ★ APPROVE gates

每一 step 結束都會等你確認再進下一 step。

---

## Stage 1: Code 專案 — 新功能（完整流程）

### 你打什麼

直接描述需求，**不用記指令**：

```
> 我想加一個 JWT 驗證功能來保護 API endpoints
```

### 自動發生（依時序）

#### Step 1.1 — UserPromptSubmit hook 觸發
`skill-router.sh` 讀你的 prompt：
- ✓ 長度 > 10 字 → 不跳過
- ✓ 不含 negative keyword（`typo`/`小改` etc.）→ 不跳過
- ✓ 命中 `加一個` keyword → 注入 hint：
  > "This looks like a new feature request. Start with /brainstorming for spec-driven flow (HARD-GATE design before code). If this is a small change, ignore this hint."

#### Step 1.2 — Main Claude 讀到 hint
Claude 看到 additionalContext，在回覆裡明確說：
> 「這像是新功能。我先用 brainstorming 跟你對話釐清需求，然後寫 spec。」

接著呼叫 `brainstorming` skill。

#### Step 1.3 — `brainstorming` skill 啟動 HARD-GATE
這個 skill 內建約束：**未經你 approve design 之前，不會寫任何 code**。
Claude 跟你逐項對話：
- 目的、TA、scope
- 提出 2-3 個方案（含 trade-off）
- 分段呈現 design

#### Step 1.4 — 寫入 spec 並 commit
Approve 後，spec 寫到 `.specify/specs/jwt-auth/spec.md`，建立 `feat/jwt-auth` branch，commit `spec: jwt-auth — requirements`。

> ★ **APPROVE gate 1**：你 review spec 同意後，Claude 才繼續

#### Step 1.5 — `/writing-plans`
Claude 主動或你打 `/writing-plans`，把 spec 轉成 task-friendly plan：
- 每個 task 標 boundary、Acceptance Criteria
- 寫到 `.specify/specs/jwt-auth/plan.md`
- commit `plan: jwt-auth — implementation plan`

> ★ **APPROVE gate 2**：你 review plan 同意

#### Step 1.6 — `/executing-plans`
Claude 讀 `subagent-driven-development` skill，逐 task dispatch `task-executor`：
1. 為 task T001 建立 worktree → `feat/jwt-auth/T001`
2. **`WorktreeCreate` hook** 觸發 `worktree-enforce.sh` 驗證命名 → ✓ 符合 `feat/*/T[0-9]*`
3. **`SubagentStart` hook** log 到 `.claude/logs/agent-activity.jsonl`
4. task-executor 是 fresh subagent，只讀 task description + `test-driven-development` skill + `karpathy-guidelines` skill
5. 它依 TDD Iron Law：先寫 failing test（commit `test(auth): [T001] ...`）→ 看 fail → 寫 minimum impl（commit `feat(auth): [T001] ...`）→ 看 pass
6. 期間每次 Edit/Write 觸發 **`PreToolUse` hooks**：
   - `branch-enforce.sh` 檢查 branch（feat/jwt-auth/T001 ✓）
   - `scope-enforce.sh` 檢查 scope（無 state file → allow all）
7. 完成後 **`SubagentStop` hook** log + 桌面通知
8. main Claude 接著 dispatch 一個 fresh `code-reviewer` subagent，做 two-stage review（spec compliance + code quality）
9. PASS → merge worktree → next task；FAIL → 把 review feedback 帶入新的 fresh task-executor 重跑（最多 retry 3 次）

#### Step 1.7 — 整批 task 完成
Main Claude 讀 `finishing-a-development-branch` skill，引導你：
- 跑全套 test
- 開 PR

#### Step 1.8 — Commit 觸發 pre-commit hook（若已裝）
- `conventional-pre-commit` 驗證每個 commit message 格式（`feat(scope): description` 等）
- `gitleaks` 掃描有沒有 hardcoded secret
- 任一 fail → commit 被擋

#### Step 1.9 — Push 觸發 permissions.deny
試圖 `git push --force` / `git push origin main` → **permissions.deny 擋下**。
正常 `git push origin feat/jwt-auth` 會通過。

### 你需要做什麼

- **3 個 ★ APPROVE gates**：spec / plan / 整體完成
- 中間發生事情看 main Claude 的進度報告，subagent 內部細節不會打擾你
- 撞到 hook 擋下時，看訊息修正

### 範例對話片段

```
> 我想加一個 JWT 驗證功能來保護 API endpoints

[skill-router 注入 hint]

Claude: 這像是新功能，我先用 brainstorming 釐清。

   1. 你的 API 目前有多少 endpoints 需要保護？
   2. token 預期存在哪？(localStorage / httpOnly cookie / Authorization header)
   3. 過期時間 / refresh 機制？

> 約 12 個 endpoints，httpOnly cookie，access 15min + refresh 7d

Claude: 了解。我提兩個方案：
   A) 自己刻 JWT middleware（控制力高，需自寫 refresh logic）
   B) 用 jose 套件 + Express middleware（標準，少維護）
   建議 B...

> B

Claude: [寫 design 到 spec.md，commit]
   ★ 請 review spec.md，approve 後我繼續

> approve

Claude: [/writing-plans → plan.md, commit]
   ★ 請 review plan.md

> approve

Claude: 開始 dispatch task-executor 處理 5 個 task。

[subagent 工作中 → 桌面通知]

Claude: T001-T005 完成，code-reviewer 全部 PASS。
   下一步建議：開 PR feat/jwt-auth → main
```

---

## Stage 2: Code 專案 — Bug 修復

### 你打什麼

```
> 登入 endpoint 在 deploy 後一直回 500，看起來是 race condition
```

### 自動發生

#### Step 2.1 — UserPromptSubmit hook
`skill-router.sh` 命中 `error` keyword → 注入 hint：
> "This looks like a bug fix. Use /bugfix for the 4-phase Report → Analyze → Fix → Verify workflow. If this is a tiny one-line fix, ignore this hint."

#### Step 2.2 — `/bugfix` 啟動
4 phase 依序執行：

**Phase 1: Report**
- 由 main Claude 親自處理（不 dispatch subagent）
- 讀使用者描述 + 相關 source code
- 寫 `.specify/bugs/BUG-20260415-001/report.md`（symptom / repro / scope / severity）
- 從 main 建立 `feat/bugfix-001` branch
- commit `docs: BUG-20260415-001 — report`
- > ★ APPROVE gate 1

**Phase 2: Analyze**
- main Claude 讀 `systematic-debugging` skill 輔助 root cause 分析
- 寫 `.specify/bugs/BUG-20260415-001/analysis.md`（root cause / fix strategy / risk / regression test plan）
- commit `docs: BUG-20260415-001 — root cause analysis`
- > ★ APPROVE gate 2

**Phase 3: Fix**
- 用 `subagent-driven-development` pattern
- dispatch fresh `task-executor` 到 worktree `feat/bugfix-001/fix`
- **WorktreeCreate hook** 驗證 → ✓ 符合 `feat/bugfix-*/fix`
- task-executor 走 TDD Iron Law：先寫 regression test（讓 bug 重現）→ 看 fail → 寫最小 fix → 看 pass
- dispatch fresh `code-reviewer` 做 two-stage review
- PASS → merge → Phase 4
- FAIL → 新 task-executor retry（最多 3 次）

**Phase 4: Verify**
- dispatch fresh `code-reviewer` 跑 regression test + 跑既有 test suite 確認沒新 regression
- 寫 verification.md
- commit `docs: BUG-20260415-001 — verification report`
- > ★ APPROVE gate 3

完成後開 PR `feat/bugfix-001` → main。

### 你需要做什麼

- 3 個 ★ APPROVE gates
- 各 phase 之間可重新 review

### 範例對話

```
> 登入 endpoint 在 deploy 後一直回 500，看起來是 race condition

[skill-router 注入 bugfix hint]

Claude: 看起來是 bug，跑 /bugfix。

[Phase 1] 我看了 src/auth/login.ts 和最近的 deploy log...
   寫了 report.md：
   - Symptom: ...
   - Repro: ...
   - Scope: src/auth/login.ts:42-67
   - Severity: critical
   ★ approve report?

> approve

[Phase 2] 讀 systematic-debugging skill 後深挖...
   Root cause: bcrypt.compare 在 async 沒 await...
   Fix strategy: 加 await + 改成 sequential
   ★ approve analysis?

> approve

[Phase 3] dispatch task-executor 寫 regression test + fix...
   [subagent 工作中]
   code-reviewer: PASS
   ★ ready for verify

[Phase 4] 跑 test suite... ALL GREEN
   verification.md 寫好，bug 已 RESOLVED
   ★ approve final?

> approve

Claude: PR 開好了：feat/bugfix-001 → main
```

---

## Stage 3: 文件專案 — 寫專利 / 規格 / 報告

### 你打什麼

```
> 我要寫一份關於我們新硬體溫度感測器的專利申請書
```

### 自動發生

#### Step 3.1 — UserPromptSubmit hook
`skill-router.sh` 命中 `專利` keyword → 注入 hint：
> "This looks like a document task. Use /write-document for the document-specific 4-phase flow."

#### Step 3.2 — `/write-document` 啟動
**這個流程跟 Code 流程根本不同**：
- 用 **persistent** writer / verifier agents（不是 ephemeral subagent）
- 不用 TDD（文件沒 test 概念）
- 不用 worktree（章節 sequential）
- 跨章節維持術語一致

5 個 phase：

**Phase 1: Spec** — main Claude 對話，寫 `.specify/specs/temp-sensor-patent/spec.md`（目的、TA、章節大綱、references、acceptance）
> ★ APPROVE gate 1

**Phase 2: Structure Plan** — main Claude 寫 plan.md（每章 purpose、key messages、長度、依賴、references、術語表）
> ★ APPROVE gate 2

**Phase 3: Chapter Tasks** — main Claude 寫 tasks.md（per-chapter task with boundary）
> ★ APPROVE gate 3

**Phase 4: Drafting Cycle**（逐章執行）
- Step 4a — dispatch persistent `writer` agent draft 該章
- Step 4b — dispatch `verifier` agent 做 fact-check + cross-reference
- Step 4c — dispatch fresh `code-reviewer` 做 plan-alignment review
- PASS → 下一章；FAIL → writer 回修（max 3 retry）

**Phase 5: Final Review** — `code-reviewer` + 你做整份終審
> ★ APPROVE gate 4

完成後開 PR。

### 你需要做什麼

- 4 個 ★ APPROVE gates
- 中間可調整章節 / 術語表

---

## Stage 4: 小型編輯（typo / comment / rename）

### 你打什麼

```
> 修一下 README 裡 "the the" 的 typo
```

### 自動發生

#### Step 4.1 — UserPromptSubmit hook
`skill-router.sh` 偵測：
- ✓ Prompt 命中 negative keyword `typo` → **直接 exit 0，不注入任何 hint**

#### Step 4.2 — Main Claude 自由處理
沒有 hint 干擾，Claude 直接 Edit README。

#### Step 4.3 — PreToolUse hook
- `branch-enforce.sh` 檢查 branch
  - 若在 `main` / `master` → **deny**（提示你切到 `feat/*` `chore/*` `docs/*` `bugfix/*`）
  - 若在 `docs/typo-fix` → ✓ allow
- `scope-enforce.sh` 若 scope 未啟用 → ✓ allow

#### Step 4.4 — PostToolUse hook
- `auto-format.sh` 若你在 setup 啟用了 markdown formatter 會自動 format

#### Step 4.5 — Stop hook
- `stop-verify.sh` 偵測有檔案變更，但 lint/typecheck 預設全註解 → no-op

### 你需要做什麼

- 確認 branch 是 `feat/chore/docs/bugfix` 開頭
- 若 branch 錯，按 deny 訊息 `git switch -c docs/typo-fix`
- 改完 commit：`git commit -m "docs: fix typo in README"`
- pre-commit hook 驗證 commit message 格式（若已啟用）

### 為什麼這樣設計

`skill-router` 對「小改」應該禮讓，不能把每個 fix 都導向 4-phase bugfix 流程。
但 branch 規則仍硬性執行 — 強制使用者習慣 feature branch workflow。

---

## Stage 5: 日常 Q&A（不要動檔案）

### 你打什麼

```
> 解釋一下 src/auth/login.ts 的 flow
```

### 自動發生

- UserPromptSubmit hook → skill-router 沒命中 keyword（"解釋" 不在規則）→ 無 hint
- Claude 用 Read tool 讀檔案、回答
- **沒有 hook 觸發**（Read 不是 Edit，不觸發 PreToolUse 規則）
- Stop hook 偵測到無檔案變更 → no-op

### 你需要做什麼

- 什麼都不用，純對話

---

## Stage 6: Opt-in Scope Enforcement

### 使用情境

你在 `feat/jwt-auth` branch 上，T002 task 應該只動 `src/auth/`，但擔心 AI 不小心摸到 `src/api/` 把它改壞。

### 你打什麼

```bash
bash .claude/scripts/scope set src/auth/ tests/auth/
```

### 自動發生

`.claude/scripts/scope` 寫入 `.claude/state/phase.json`：
```json
{
  "scope_paths": ["src/auth/", "tests/auth/"],
  "started_at": "2026-04-15T14:30:00+08:00"
}
```

之後 main Claude 或任何 subagent 嘗試 Edit/Write：
- `PreToolUse` → `scope-enforce.sh` 讀 phase.json
- 檔案路徑包含 `src/auth/` 或 `tests/auth/` → ✓ allow
- 否則 → **deny**，回訊息：
  > "File src/api/foo.py is outside current task scope. Allowed paths: src/auth/ tests/auth/. Run 'bash .claude/scripts/scope set <path>' to update, or 'bash .claude/scripts/scope clear' to disable enforcement."

### 解除

完成 task 後：
```bash
bash .claude/scripts/scope clear
```

state file 移除，scope-enforce 退回「allow all」。

### 你需要做什麼

- 自己決定何時開、何時關
- 不會自動啟用，不影響預設使用體驗

---

## Stage 7: 撞到 enforcement 時

### 7.1 在 main / master / 雜 branch 上嘗試編輯

**現象：** Claude 嘗試 Edit/Write 後立即收到：
```
permission denied: Cannot edit on "main". Create a feat/{name} (or chore/*, docs/*, bugfix/*) branch first.
```

**修法：**
```bash
git switch -c feat/whatever
```

### 7.2 Worktree branch 命名違規

**現象：** dispatch task-executor 時建 worktree `feat/foo/bar` → block：
```
Worktree branch "feat/foo/bar" starts with feat/ but does not match canonical sub-patterns
```

**修法：** 用 canonical naming：
- `feat/{feature}/T001`
- `feat/bugfix-{id}/fix`
- `feat/bugfix-{id}/T001`

### 7.3 Commit message 格式錯

**現象：**
```bash
$ git commit -m "quick fix"
[INFO] Initializing environment for ...
✗ commit-msg
- hook id: conventional-pre-commit
- exit code: 1

Bad commit message, expected pattern: type(scope): subject
```

**修法：**
```bash
git commit -m "fix: race condition in login"
# 或：
git commit -m "fix(auth): race condition in login"
```

合法 type：`feat fix docs style refactor test chore perf ci spec plan tasks draft verify`

### 7.4 Gitleaks 偵測到 secret

**現象：** commit 被擋，gitleaks 輸出哪一行可疑。

**修法：** 把 secret 移到 `.env`、加入 `.gitignore`、改用 secret manager。

### 7.5 試圖 git push --force 或 push to main

**現象：**
```
permission denied: Bash(git push --force*)
```

**修法：** 別這樣做。如果非要，請和維護者討論。

### 7.6 試圖 rm -rf

**現象：**
```
permission denied: Bash(rm -rf *)
```

**修法：** 用更精準的 path，不要 wildcard。

---

## 附錄 A: Hook 觸發時序圖

```
你打字
  │
  ▼
┌─────────────────────────────────────┐
│ UserPromptSubmit hook               │
│   → skill-router.sh                 │
│     - 短於 10 字 → skip             │
│     - negative keyword → skip       │
│     - 命中規則 → 注入 additionalContext │
└─────────────────────────────────────┘
  │
  ▼
Main Claude 處理 prompt
  │ （可能呼叫 skill）
  │
  ├─ Tool calls (Edit/Write/Bash) ────┐
  │                                   │
  │   ┌────────────────────────────┐ │
  │   │ PreToolUse hooks (Edit|Write):│
  │   │   1. branch-enforce.sh     │ │
  │   │   2. scope-enforce.sh      │ │
  │   │ 任一 deny → 整個 tool call 被擋 │
  │   └────────────────────────────┘ │
  │                  │                │
  │                  ▼                │
  │            (執行 tool)             │
  │                  │                │
  │   ┌────────────────────────────┐ │
  │   │ PostToolUse hooks (Edit):   │ │
  │   │   - auto-format.sh          │ │
  │   └────────────────────────────┘ │
  │                                   │
  │   permissions.deny 同時擋 Bash 違規 │
  │                                   │
  ├─ Subagent dispatch ───────────────┤
  │                                   │
  │   ┌────────────────────────────┐ │
  │   │ SubagentStart hook         │ │
  │   │   → log to jsonl           │ │
  │   └────────────────────────────┘ │
  │                  │                │
  │   ┌──────────────┴────────────┐  │
  │   │ Subagent execution       │  │
  │   │ (受 isolation: worktree) │  │
  │   └──────────────┬────────────┘  │
  │                  │                │
  │   ┌────────────────────────────┐ │
  │   │ SubagentStop hook           │ │
  │   │   → log + 桌面通知           │ │
  │   └────────────────────────────┘ │
  │                                   │
  ├─ Worktree create ─────────────────┤
  │                                   │
  │   ┌────────────────────────────┐ │
  │   │ WorktreeCreate hook        │ │
  │   │   → worktree-enforce.sh    │ │
  │   │   非 canonical → block     │ │
  │   └────────────────────────────┘ │
  │                                   │
  ▼
回覆完成
  │
  ▼
┌─────────────────────────────────────┐
│ Stop hook                            │
│   → stop-verify.sh                   │
│   - 無變更 → no-op                    │
│   - 有變更 → lint/typecheck（opt-in）│
└─────────────────────────────────────┘

外加：
- Notification hook：Claude 需要輸入時觸發 → 桌面通知
- pre-commit hook（git native，bootstrap.sh 安裝）：
    git commit 時驗證 conventional commit + gitleaks
```

---

## 附錄 B: 不會被擋下的小事

下面這些 prompt **不會** 觸發 skill-router 強制路由（保持輕量）：

- 短於 10 字的 prompt
- 含 `typo` / `comment` / `rename` / `format` / `quick` / `小改` / `小修` / `改個字` / `拼字` / `註解` / `重命名` 的 prompt
- 純 Q&A（解釋程式碼、查 doc、看歷史 commit）

但這些**仍會觸發** branch-enforce：

- 任何 Edit/Write tool call，無論流程強度

換言之：**workflow 是建議性的，branch 規則是強制的**。

---

## 附錄 C: 使用心法

1. **不要記指令 — 直接描述意圖**。skill-router 會幫你導到對的 skill。
2. **HARD-GATE 不是擋路 — 是保護你**。`brainstorming` 不准未經 approve 寫 code，是因為 LLM 經常假設錯方向。
3. **撞到 hook 擋下不是 bug — 是 feature**。訊息會告訴你怎麼修。
4. **Subagent 用完即棄 — 不要期待跨 task 記憶**。code 風格 / 設計決定要寫進 plan 或 CLAUDE.md。
5. **scope enforcement 是 opt-in — 預設不擾**。只在你明確擔心 AI 越界時開。
6. **小改不需 4-phase**。改 typo 就改 typo，AI 不會強迫你跑 brainstorming。
