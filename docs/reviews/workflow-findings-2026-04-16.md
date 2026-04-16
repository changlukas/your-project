# write-document Workflow Findings

**Date:** 2026-04-16
**Test case:** Section-by-section review of a patent concept report (10 sections)
**Workflow used:** Adapted from `write-document` Phase 4b+4c+5

---

## Summary

`write-document` skill 設計為從零撰寫文件的 4-phase 流程。在「評估既有文件」的場景下，
Phase 1-3 完全不適用，Phase 4 的 agent dispatch 模型（spawn writer/verifier/code-reviewer）
在評估任務中不如「同一 context 角色切換」有效。

測試過程中識別出 5 個 workflow gap，已產出新 skill `/review-document` 作為改進提案。

---

## Gap 1: 缺少「評估既有文件」的流程

**現狀：** `write-document` 假設從零開始（Spec → Plan → Tasks → Draft）。
對既有文件的評估沒有對應入口。

**影響：** 使用者要評估一份已完成的文件時，必須跳過 Phase 1-3，
手動適配 Phase 4 的 verifier/reviewer 角色。

**改進：** 新增 `/review-document` skill，4 phase 流程：
Scope Definition → Section Decomposition → Per-Section Review Cycle → Consolidation

---

## Gap 2: Agent dispatch 對評估任務效果不佳

**現狀：** `write-document` 規定 spawn persistent writer/verifier/code-reviewer agents。

**測試發現：** 評估任務在同一 context 中用角色切換效果更好，原因：
1. 前一節的收斂結論需要帶入下一節（agent 看不到先前 context）
2. 使用者的即時洞察會改變評估方向（agent 無法接收 mid-stream pivot）
3. Verifier 發現的問題直接影響 Reviewer 判斷（分開 dispatch 會斷裂連結）

**改進：** `/review-document` 預設 main Claude 角色切換，不強制 spawn agent。
Research 需求透過 Agent tool 處理（spawn research agent 做文獻查證），
但 verifier + reviewer 角色在同一 context 中執行。

---

## Gap 3: 缺少 Research Gate

**現狀：** `write-document` 的 verifier 步驟假設 verifier 自己就知道技術事實。

**測試發現：** 多個 section 需要外部 research 才能做事實查核：
- §7 前案檢索 → 需要查 Markov Prefetcher、NVIDIA Access Counter
- §6 實施例 → 需要查 MoE 文獻的具體數據
- §4 新穎性 → 需要確認其他硬體方案的具體機制

**改進：** `/review-document` 在 verifier 前加 Research Gate：
「本節涉及的技術宣稱，是否有足夠資訊判斷？若否，先 spawn research agent。」

---

## Gap 4: Gate 缺少 PIVOT 機制

**現狀：** `write-document` 的 Gate 只有 PASS / FAIL（retry max 3）。

**測試發現：** 評估過程中發生了 3 次 PIVOT（方向性修正）：
1. PIVOT 1: 使用者指出 per-MC domain ≈ CHMU 位置 → 核心差異化改變
2. PIVOT 2: 使用者指出 IRQ = 回報 OS → 通知機制差異不成立
3. PIVOT 3: 使用者確認走演算法而非硬體路線 → Claim 結構全改

這些不是「回修」，而是「前提改變」。現有 Gate 無法處理。

**改進：** Gate 新增第三種結果 PIVOT：
暫停 → 與使用者確認新方向 → 標記前面受影響的 section 需 re-evaluate → 繼續

---

## Gap 5: Git 流程對文件評估不適用

**現狀：** `write-document` 每個 task commit to `feat/doc-{name}` branch。

**測試發現：** 評估任務的產出是 review report 和修訂 plan，不是文件本身的修改。
原文件可能不在 git 中。commit 什麼、commit 到哪都不明確。

**改進：** `/review-document` 的產出是結構化 review report（markdown），
不修改原文件，不強制 git 流程。如需 git，由使用者決定。

---

## Proposed Changes

| 類型 | 路徑 | 說明 |
|---|---|---|
| 新增 | `.claude/skills/review-document/SKILL.md` | 新 skill：既有文件逐節評估流程 |
| 建議修改 | `.claude/skills/write-document/SKILL.md` | 加一段「本 skill 適用於撰寫新文件，評估既有文件請用 /review-document」|
| 建議修改 | `README.md` | 在「內建的工作流入口」中新增 `/review-document` |
