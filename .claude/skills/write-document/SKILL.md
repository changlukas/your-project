---
name: write-document
description: >
  Spec-driven workflow for DOCUMENT projects (specs, patents, technical reports, white papers).
  Parallel to Superpowers' code-oriented skills. Dispatches to writer and verifier agents.
  Use when: "write document", "write patent", "specification document", "technical report",
  "draft chapter", "write whitepaper".
disable-model-invocation: true
---

# Write Document Workflow

文件專案的 spec-driven 流程。**不使用** Superpowers 的 code-oriented skills（brainstorming、
writing-plans、subagent-driven-development、test-driven-development），改走文件專屬路徑。

## 使用時機

- 專案主要產出為純文件：技術規格書、專利申請、技術報告、白皮書、設計文件集
- **不適用**於「為了產生 code 而寫的設計文件」（那種用 `brainstorming` skill）

## 與 Code 專案的根本差異

| 面向 | Code 專案（Superpowers） | 文件專案（本 skill） |
|---|---|---|
| 執行者 | Ephemeral subagent per task | **Persistent** writer/verifier agents |
| 測試 | TDD Iron Law | 無 test 概念，改用 fact-check + cross-reference |
| 隔離 | Worktree per task | 單一 branch sequential（章節通常有脈絡依賴） |
| Review | code-reviewer two-stage | code-reviewer（plan-alignment 檢查仍有效）+ verifier |
| 失敗重做 | Dispatch 新 fresh subagent | 同 writer 回修（context 連續有價值） |

### 為什麼文件專案用 persistent agents？

文件撰寫需要**跨章節語氣一致、術語統一、敘事脈絡連貫**。每次 fresh subagent 會產生術語飄移
（例如第 3 章叫「溫度感測器」，第 5 章變「熱偵測器」）。Persistent writer 保有累積的風格共識。

## 4 Phase 流程

### Phase 1: Specification

**執行者：** main Claude（不 spawn subagent）

與使用者對話產出文件需求：
- 文件目的（TA、applications、交付期限）
- 範圍（涵蓋什麼、不涵蓋什麼）
- 章節大綱草案
- 參考來源（prior art、規格、標準、既有文件）
- 驗收條件（誰審、怎麼審、通過標準）

**對話原則：**
- 一次只問一個問題，讓使用者好回答
- 對「技術細節」與「敘事策略」兩類問題分開問
- 不要一次產生完整 spec；分段呈現、分段 APPROVE

**產出：** `.specify/specs/{name}/spec.md`

spec.md 結構：
```markdown
# Document Spec: {title}

## Purpose
{為什麼要寫這份文件}

## Target Audience
{讀者是誰、他們的 context level}

## Scope
- In: ...
- Out: ...

## Structure (Draft)
1. Chapter 1 - ...
2. Chapter 2 - ...
...

## References
- [ref-1] source description
- [ref-2] ...

## Acceptance Criteria
- ...
```

**Git：** 從 main 建立 `feat/doc-{name}` branch，commit `spec: doc-{name} — requirements`
**Gate：** ★ 使用者 approve

---

### Phase 2: Structure Plan

**執行者：** main Claude

將 spec 映射為詳細章節結構：
- 每章節的 purpose + 關鍵訊息 + 長度估計
- 章節之間的依賴關係（章 5 引用章 3 的定義等）
- 每章的 required references（哪些 prior art / 規格要引用）
- 術語表草案（統一術語，避免飄移）

**產出：** `.specify/specs/{name}/plan.md`

plan.md 結構：
```markdown
# Document Plan: {title}

## Terminology
| Term | Definition | Usage |
|---|---|---|
| ... | ... | 避免用 X |

## Chapters

### Ch1: {title}
- Purpose: ...
- Key messages: ...
- Length: ~{N} pages
- Depends on: (none) or Ch{M}
- References: [ref-1], [ref-3]
- Risks: ...

### Ch2: ...
```

**Git：** commit `plan: doc-{name} — structure and terminology`
**Gate：** ★ 使用者 approve

---

### Phase 3: Chapter Tasks

**執行者：** main Claude

將 plan 拆解為 per-chapter tasks：
- 每個 task 對應一個章節或一個獨立段落
- 標注 Boundary（只能寫哪些段落）、Depends（哪些前置章節要先完成）
- 分 Wave（Wave 1 為無依賴章節，可並行；Wave 2 依賴 Wave 1；依此類推）

**產出：** `.specify/specs/{name}/tasks.md`

tasks.md 結構：
```markdown
# Document Tasks: {title}

## Wave 1
### T001: Draft Ch1 (Introduction)
- Executor: writer
- Boundary: Chapter 1 only
- Depends: (none)
- Acceptance: covers purpose, scope, TA summary; ~3 pages

### T002: Draft Ch2 (Background)
- Executor: writer
- Boundary: Chapter 2 only
- Depends: (none)
- Acceptance: ...

## Wave 2
### T003: Draft Ch3 (System Overview)
- Executor: writer
- Boundary: Chapter 3 only
- Depends: T001 (references Intro definitions)
- Acceptance: ...
```

**Git：** commit `tasks: doc-{name} — task decomposition`
**Gate：** ★ 使用者 approve

---

### Phase 4: Drafting Cycle（逐 task）

按 Wave 順序執行。同 Wave 內的 tasks 可 sequential（文件專案通常不開 worktree）。

每個 task 走 3 步：

#### Step 4a: Draft
**Agent：** `writer`
**指派指令：** 「撰寫 T00X：{chapter title}。依據 plan.md 的 key messages 和 required references。
嚴格不跨越章節 boundary，不確定的技術細節標記 [NEEDS VERIFICATION]。」
**產出：** chapter draft in `.specify/specs/{name}/drafts/T00X-{slug}.md`（或直接產出到最終文件路徑）
**Git：** commit `draft(doc): [T00X] {chapter title}`

#### Step 4b: Verify
**Agent：** `verifier`
**指派指令：** 「查核 T00X 的技術事實、引用一致性、術語一致性、邏輯連貫。
對比 plan.md 的 references，確認每個引用來源可追溯。產出 JSON report。」
**產出：** JSON `{section, status: PASS|FAIL, issues: [{type, location, description, evidence}]}`
**Git：** commit `verify(doc): [T00X] {chapter title}`

#### Step 4c: Review
**Agent：** `code-reviewer`（vendored from Superpowers）
**指派指令：** 「對 T00X 做 two-stage review：
  Stage 1 - Plan alignment：本章是否符合 plan.md 的 key messages 和 acceptance criteria？
  Stage 2 - Quality：結構、用詞、語氣、可讀性、術語一致性。」
**產出：** structured review report

#### Gate
- **PASS**（零 critical/major issues）→ 下一個 task
- **FAIL** → writer 回修，保留 context（與 Code 專案不同，不 dispatch 新 agent），最多重試 3 次
- 3 次仍 FAIL → 暫停呈報使用者

Wave N 全部完成才開始 Wave N+1。

---

### Phase 5: Final Review

**Agent：** `code-reviewer` + 使用者
對整份文件做 final review。確認：
- 各章節銜接順暢、無術語飄移
- 所有引用已驗證
- 整體長度和比例合理
- 無 `[NEEDS VERIFICATION]` 殘留

**產出：** `.specify/specs/{name}/final-review.md`
**Git：** commit `docs: doc-{name} — final review`
**Gate：** ★ 使用者 approve

**Phase 5 完成後：** 在 `feat/doc-{name}` 上建 PR → main

---

## 流程圖

```
/write-document "description"
    │
    ▼
Phase 1: Specification ──→ main Claude 對話 → ★ approve
    │                       git: create feat/doc-{name}, commit spec
    ▼
Phase 2: Structure Plan ──→ main Claude → ★ approve
    │                        git: commit plan
    ▼
Phase 3: Chapter Tasks ──→ main Claude → ★ approve
    │                       git: commit tasks
    ▼
Phase 4: Per-chapter cycle（sequential by wave）

    ┌──→ writer(draft) → verifier → code-reviewer ──→ PASS? ─→ next
    │                                                   │
    └──────────── retry (max 3, same writer) ◄──────────┘

    │
    ▼
Phase 5: Final review ──→ code-reviewer + 使用者 → ★ approve
    │                      git: commit final review
    ▼
PR → main
```

---

## 與其他 skill 的互動

- **不使用** `brainstorming`（文件對話模式與 code 不同）
- **不使用** `writing-plans`（plan 結構不同）
- **不使用** `subagent-driven-development`（persistent agents 有其價值）
- **不使用** `test-driven-development`（文件無 test 概念）
- **可選使用** `karpathy-guidelines`（Simplicity First 對文件同樣適用：不寫未被要求的內容）
- **使用** `verification-before-completion` 在每章 commit 前做 self-check
