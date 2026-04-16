---
name: review-document
description: >
  Section-by-section review workflow for EXISTING documents (specs, patents, technical reports).
  Parallel to write-document but for evaluation, not creation.
  Use when: "review document", "evaluate this patent", "review this report",
  "check this spec", "audit this document section by section".
disable-model-invocation: true
---

# Review Document Workflow

既有文件的逐節評估流程。與 `write-document`（從零撰寫）互補，專為「拿到一份已完成的文件，
需要系統性評估」的場景設計。

## 使用時機

- 文件已完成（初稿或更成熟），需要系統性評估
- 專利概念報告、技術規格書、白皮書的 review
- 需要同時做事實查核（verify）與品質審閱（review）
- 評估過程可能需要外部 research（文獻查證、prior art 搜尋）

## 與 write-document 的根本差異

| 面向 | write-document | review-document（本 skill） |
|---|---|---|
| 起點 | 從零開始，需要 spec | 文件已存在，需要評估 |
| Phase 1-3 | Spec → Plan → Tasks | 讀取文件 → 定義評估重點 → 拆 review tasks |
| 執行者 | Persistent writer/verifier agents | **Main Claude 角色切換**（verifier + reviewer 在同一 context）|
| Research | 不需要 | **可能需要**——verifier 前加 research gate |
| Gate | PASS / FAIL / retry | PASS / FAIL / **PIVOT**（方向修正）|
| Git | commit per chapter draft | 產出 review report，不修改原文件 |
| 產出 | 文件本身 | Structured review report + 修訂 plan |

### 為什麼不 spawn 獨立 agent？

評估任務的特性決定了在同一 context 中用角色切換比 spawn agent 更好：

1. **前一節的收斂結論需要帶入下一節**——獨立 agent 看不到先前對話
2. **使用者的即時洞察可能改變評估方向**——例如使用者指出「這和 X 方案一樣」，立刻影響後續所有判斷
3. **Verifier 發現的問題直接影響 Reviewer 的判斷**——分開 dispatch 會斷裂這個連結

## 4 Phase 流程

### Phase 1: Scope Definition

**執行者：** main Claude

與使用者對話確認：
- 要評估的文件是什麼
- 評估重點（技術正確性？前案對比？敘事品質？Claim 防禦？全部？）
- 使用者已知的外部回饋（例如主管意見、同事挑戰）
- 是否有參考文件（review notes、會議記錄）

**對話原則：**
- 一次問清楚範圍和重點，不要逐步擠牙膏
- 確認使用者希望的輸出格式（逐節報告？整體摘要？修訂 plan？）

**產出：** 口頭對齊（不產檔案），進入 Phase 2
**Gate：** 使用者確認範圍

---

### Phase 2: Section Decomposition

**執行者：** main Claude

讀取文件，拆成可獨立評估的 section。每個 section 標註：
- 章節名稱與範圍
- 與評估重點的關聯度
- 是否可能需要 research（文獻查證、prior art 搜尋）

**產出：** 口頭確認 section 清單和評估順序
**Gate：** 使用者確認（可選跳過某些 section）

---

### Phase 3: Per-Section Review Cycle

按約定順序，逐 section 執行。每個 section 走 4 步：

#### Step 3a: Research Gate（條件觸發）

**判斷：** 本節涉及的技術宣稱，是否有足夠資訊判斷正確性？

- **有**：直接進 Step 3b
- **沒有**：spawn research agent 查證，取得結果後再進 Step 3b

Research agent 的任務範例：
- 查證某篇論文的具體數據
- 確認某個 prior art 的詳細機制
- 搜尋文件遺漏的相關工作

#### Step 3b: Verifier（事實查核）

角色切換為 Verifier，檢查：
- 技術事實正確性
- 引用/數據可追溯性
- 術語一致性
- 與文件其他部分的一致性

產出：per-item 檢查結果表

#### Step 3c: Reviewer（品質審閱）

角色切換為 Reviewer，聚焦使用者定義的評估重點，例如：
- 對比邏輯是否成立
- 邊界是否清晰
- 實施例是否適合
- Claim 是否可防禦

產出：結構化的 review 意見

#### Step 3d: Gate

三種結果：

- **PASS**（零 critical/major issues）→ 下一 section
- **FAIL**（有 issues 但方向正確）→ 記錄 issues，下一 section
  - 與 write-document 不同：不「回修」，因為我們在評估不在撰寫
  - Issues 累積到 Phase 4 的修訂 plan 中
- **PIVOT**（發現需要改變前提）→ 暫停，與使用者確認新方向
  - 例如：使用者指出「這個架構假設不成立」
  - 確認後，前面已評估的 section 中受影響的結論需要標記 re-evaluate
  - 繼續後續 section 時帶入新前提

---

### Phase 4: Consolidation

**執行者：** main Claude

彙整所有 section 的評估結果，產出：

1. **問題總覽**：所有 issues 按嚴重度排序，標注影響範圍
2. **核心問題收斂**：多個 issues 是否指向同一個根本問題
3. **修訂 Plan**：分 phase、分優先順序的具體修訂建議
4. **PIVOT 記錄**：評估過程中發生的方向修正及其影響

**產出格式：**

```markdown
# Review Report: {document title}

## Scope
- 評估重點：...
- 外部回饋：...

## Per-Section Results
### Section N: {title}
- Gate: PASS / FAIL / PIVOT
- Issues: [list]
- Key findings: [list]

## Problem Consolidation
- 根本問題 1：...（影響 Section X, Y, Z）
- 根本問題 2：...

## Revision Plan
### Phase 1 (Week 1): ...
### Phase 2 (Week 2): ...

## PIVOT Log
- PIVOT 1: {trigger} → {new direction} → {affected sections}
```

**Gate：** ★ 使用者 approve

---

## 流程圖

```
/review-document "description"
    │
    ▼
Phase 1: Scope Definition ──→ main Claude 對話 → ★ approve
    │
    ▼
Phase 2: Section Decomposition ──→ main Claude → ★ approve
    │
    ▼
Phase 3: Per-section cycle（sequential）

    ┌──→ [Research Gate] → Verifier → Reviewer → Gate
    │                                              │
    │         ┌─── PASS ───→ next section          │
    │         │                                    │
    │         ├─── FAIL ───→ record issues → next  │
    │         │                                    │
    │         └─── PIVOT ──→ confirm with user ────┘
    │                        re-evaluate affected
    │
    ▼
Phase 4: Consolidation ──→ review report + revision plan → ★ approve
```

## 與其他 skill 的互動

- **可使用** `verification-before-completion` 確認 review report 的完整性
- **可使用** Agent tool 做 research（Phase 3 Step 3a）
- **不使用** `write-document`（評估和撰寫是不同流程）
- **不使用** `brainstorming`（已有文件，不需要 spec 階段對話）
- **不使用** `subagent-driven-development`（評估任務在同一 context 中更好）
