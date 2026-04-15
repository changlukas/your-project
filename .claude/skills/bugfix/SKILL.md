---
name: bugfix
description: >
  Bug fix workflow for code projects with 4 phases: Report → Analyze → Fix → Verify.
  Use when: "fix bug", "bugfix", "investigate issue", "regression", "something broken".
disable-model-invocation: true
---

# Bug Fix Workflow

你是 Bug Fix Orchestrator。4 個 phase 依序執行，每個 phase 結束呈報使用者 ★ APPROVE。
Phase 1-2 由 main Claude 直接處理（讀 `systematic-debugging` skill 協助分析）；
Phase 3 dispatch `task-executor` 和 `code-reviewer` subagents；Phase 4 dispatch `code-reviewer`。

## 執行規則

1. 嚴格按 Phase 順序執行
2. Phase 1-2 由 main Claude 親自處理；Phase 3-4 dispatch subagent
3. 每個 Phase 完成後呈報產出並等待 ★ APPROVE
4. 你自己不修 bug、不寫 test — 你只協調

## 輸入

使用者提供：
- Bug 描述（symptom / error message / 可重現步驟）
- 受影響的檔案或模組（可選）

產出一個 bug-id，格式 `BUG-{yyyymmdd}-{nnn}`。

---

## Git 管控

### Branch 策略

```
main（受保護）
 └── feat/bugfix-{bug-id}（所有 phase 在此 branch 工作，Phase 3 開 worktree）
      └── feat/bugfix-{bug-id}/fix（Phase 3 worktree）
```

### Commit Convention

| Phase | Prefix | Example |
|-------|--------|---------|
| 1 | `docs:` | `docs: BUG-20260414-001 — report` |
| 2 | `docs:` | `docs: BUG-20260414-001 — root cause analysis` |
| 3 | `fix:` | `fix(auth): [BUG-20260414-001] prevent null token crash` |
| 3 | `test:` | `test(auth): [BUG-20260414-001] regression test` |
| 4 | `docs:` | `docs: BUG-20260414-001 — verification report` |

---

## Phase 1: Report

**執行者：** main Claude（唯讀分析，不 spawn subagent）
**做法：** 讀取使用者描述 + 相關檔案，產出結構化 report
**輸入:** 使用者描述 + 相關檔案
**產出:** `.specify/bugs/{bug-id}/report.md`

report.md 結構：
```markdown
# BUG-{id}: {short title}

## Symptom
{觀察到的錯誤行為}

## Reproduction
1. ...
2. ...

## Scope
- Affected files: ...
- Affected modules: ...
- Severity: critical | major | minor

## Environment
- Branch/commit: ...
- OS/platform: ...
```

**Git:** 從 main 建立 `feat/bugfix-{bug-id}` branch，commit `docs: {bug-id} — report`
**Gate:** ★ 使用者 approve

---

## Phase 2: Analyze

**執行者：** main Claude
**建議先讀：** `systematic-debugging` skill（vendored from Superpowers）作為 root-cause 分析框架
**輸入:** report.md + 相關 source code（唯讀）
**產出:** `.specify/bugs/{bug-id}/analysis.md`

analysis.md 結構：
```markdown
# BUG-{id}: Root Cause Analysis

## Root Cause
{為什麼會發生 — 精確到 file:line}

## Why It Wasn't Caught
{測試覆蓋缺口 / edge case 分析}

## Fix Strategy
{最小修改原則下的建議修法}

## Risk
{修改可能連帶影響的區域}

## Regression Test Plan
{需要新增哪些 test case}
```

**Git:** commit `docs: {bug-id} — root cause analysis`
**Gate:** ★ 使用者 approve（確認修法方向再進入 Phase 3）

---

## Phase 3: Fix

使用 Superpowers 的 `subagent-driven-development` pattern，走 TDD Iron Law：
先寫 failing regression test，再寫最小 fix 讓 test pass。

### Step 3a: Dispatch task-executor（ephemeral subagent in worktree）
**Agent:** `task-executor`（fresh subagent，worktree 隔離）
**Git:** worktree branch `feat/bugfix-{bug-id}/fix`
**指派指令:** 「根據 analysis.md 的 Regression Test Plan 和 Fix Strategy，
  走 TDD Iron Law：先寫 regression test → 看 test fail（驗證 bug 重現）→ 寫最小 fix → test pass。
  task boundary: analysis.md 指定的檔案範圍。不擴大 scope。」
**產出:**
- `test(scope): [BUG-{id}] regression test` commit
- `fix(scope): [BUG-{id}] description` commit

### Step 3b: Dispatch code-reviewer（ephemeral subagent）
**Agent:** `code-reviewer`（vendored from Superpowers，唯讀 two-stage review）
**指派指令:** 「對 BUG-{id} 的 fix 做 two-stage review：
  Stage 1 - Plan alignment：fix 是否符合 analysis.md 的 Fix Strategy？是否未擴大 scope？
  Stage 2 - Quality：test 是否實際驗證 bug？fix 是否過度設計？」
**產出:** structured review report (PASS / FAIL)

### Gate
- **PASS** → merge worktree → `feat/bugfix-{bug-id}` → Phase 4
- **FAIL** → dispatch **新的** fresh task-executor（不復用失敗的 subagent），feedback 帶入 task description，最多 retry 3 次
- 3 次仍 FAIL → 暫停呈報使用者

---

## Phase 4: Verify

**Agent:** `code-reviewer`（fresh dispatch，唯讀）
**指派指令:** 「執行 regression test，確認 bug 已修復；跑既有 test suite 確認沒引入 regression」
**輸入:** 全部 changes + analysis.md
**產出:** `.specify/bugs/{bug-id}/verification.md`

verification.md 結構：
```markdown
# BUG-{id}: Verification

## Test Results
- Regression test: PASS/FAIL
- Existing test suite: PASS/FAIL

## Coverage
{新增 test 覆蓋的 edge cases}

## Sign-off
Status: RESOLVED | NEEDS_REWORK
```

**Git:** commit `docs: {bug-id} — verification report`
**Gate:** ★ 使用者 approve

**Phase 4 完成後：** 在 `feat/bugfix-{bug-id}` 上建 PR → main

---

## 流程圖

```
/bugfix "description"
    │
    ▼
Phase 1: Report ──→ main Claude → ★ approve
    │                git: create feat/bugfix-{id}, commit report
    ▼
Phase 2: Analyze ──→ main Claude (reads systematic-debugging skill) → ★ approve
    │                 git: commit analysis
    ▼
Phase 3: Fix ──→ task-executor(worktree, TDD) → code-reviewer ──→ PASS? ─→ merge
    │                                                               │
    │                                                               └─ retry with fresh task-executor (max 3)
    ▼
Phase 4: Verify ──→ code-reviewer → ★ approve
    │                git: commit verification
    ▼
PR → main
```
