# Document Tasks: Patent Concept Report Revision — Phase 1

## Shared Ontology

所有 agent/task 共用 `plan.md` 的 Terminology 表。任何產出必須使用新術語，不得使用禁用術語。

## Interface Contracts

### Ch1 → Ch2 Contract

Ch1 完成後 export 以下概念供 Ch2 引用（Ch2 並行時可用 plan.md 中的定義先行草擬）：

| 概念 | 定義（placeholder，Ch1 完成後以實際文字取代） |
|---|---|
| flat mode | HBM 與 DDR 為獨立可定址記憶體空間，軟體決定資料放置 |
| cache mode | HBM 作為 DDR 的 last-level cache，硬體自動管理 |
| cache mode 限制 | tag overhead、cacheline 粒度、無預測、thrashing |
| 邊界 | 本案管 flat mode 下 DRAM-class 層級之間的搬遷決策輔助 |
| 記憶體層級 | 近端（HBM）/ 遠端（Host DDR）/ 擴展（CXL memory） |

### Ch2 → Ch3 Contract

| 概念 | 定義 |
|---|---|
| 現有機制 6 類 | 軟體配置 / fault 驅動 / OS 掃描 / HBM cache mode / GPU access counter / CXL CHMU |
| 共同缺口 | 無預測能力——無法通知尚未被存取的 region |
| 適用場景 | MoE（★★★）、Embedding table（★★★）、Multi-model（★★） |
| 不適用場景 | LLM layer-by-layer、KV cache、一般伺服器 NUMA |

### Ch3 → Ch4, Ch5 Contract

| 概念 | 定義 |
|---|---|
| 資料溫度評估引擎 | 整合時間/空間/序列三維度，更新同一溫度分數 |
| 行為學習表 | predecessor/successor/confidence 結構，溫度轉換事件觸發學習 |
| Markov 差異 | 聚合+過濾（非逐筆記錄）、狀態轉換序列（非地址序列）、migration 成本不對稱 |
| 通知機制 | hint queue (ring buffer) + interrupt/polling，與 CHMU 通知路徑相似 |

### Ch4 → Ch5 Contract

| 概念 | 定義 |
|---|---|
| 新穎性 #1 | 溫度狀態轉換序列的自主學習與預測 |
| 新穎性 #2 | 多維度評估的統一溫度分數架構 |
| 新穎性 #3 | 部署位置的彈性 |

---

## Wave 1（Ch1 ∥ Ch2）

### T001: 修訂 §1 背景

- **Executor:** writer（persistent）
- **Boundary:** §1 背景 only（report lines 9-39 對應內容）
- **Depends:** 無
- **Input:** 原文 §1 + plan.md Ch1 key messages + research-notes.md
- **Deliverable:** 修訂後的 §1 全文
- **Acceptance:**
  - [ ] cache mode vs flat mode 差異有完整解釋（非專業讀者也能理解）
  - [ ] 說明業界為何越來越走 flat mode（H100, MI300X, CXL）
  - [ ] cache mode 限制列出：tag overhead、cacheline 粒度、無預測、thrashing
  - [ ] 邊界明確：本案管 flat mode 下 DRAM-class 層級，不管 cache/SRAM/scratchpad
  - [ ] 移除 Intel Optane、移除 SRAM/scratchpad 歸類為「近端」
  - [ ] 所有新術語正確使用，無禁用術語
  - [ ] ~1.5 頁

### T002: 修訂 §2 問題定義

- **Executor:** writer（persistent）
- **Boundary:** §2 問題定義 only（report lines 42-71 對應內容）
- **Depends:** 無（可與 T001 並行；引用 Ch1 概念時使用 interface contract placeholder）
- **Input:** 原文 §2 + plan.md Ch2 key messages + research-notes.md（§3 embedding 數據）+ review.md（主管回饋）
- **Deliverable:** 修訂後的 §2 全文
- **Acceptance:**
  - [ ] 現有機制表擴充為 6 類（+HBM cache mode, +GPU Access Counter, +CXL 3.1 CHMU）
  - [ ] CXL 版本正確標注為 3.1（非 3.2）
  - [ ] 每個機制的限制有具體描述，不只一句話
  - [ ] 「共同缺口 = 無預測能力」明確點出
  - [ ] 量化佐證：OS 掃描秒級 vs AI workload pattern ms 級
  - [ ] 適用場景 3 個 + 不適用場景 3 個，正面定義
  - [ ] 適用/不適用場景附簡短理由（1-2 句）
  - [ ] 引用 Ch1 的 flat mode / cache mode 時使用 contract 中的定義
  - [ ] 所有新術語正確使用
  - [ ] ~2 頁

### Reconciliation Gate（Wave 1 完成後）

- [ ] Ch2 引用 Ch1 的術語與 Ch1 實際產出完全一致
- [ ] Ch1 的邊界定義與 Ch2 的適用場景不矛盾
- [ ] 若有不一致，修正 Ch2（因為 Ch1 是定義源）

---

## Wave 2

### T003: 修訂 §3 解決方法

- **Executor:** writer（persistent）
- **Boundary:** §3 解決方法 only（report lines 75-276 對應內容）
- **Depends:** T001 + T002（需要 Ch1 的邊界定義 + Ch2 的「共同缺口」）
- **Input:** 原文 §3 + plan.md Ch3 key messages + research-notes.md（Markov prefetcher 結構 + 專利寫作風格）+ review.md（concrete walkthrough 範例）
- **Deliverable:** 修訂後的 §3 全文
- **Acceptance:**
  - [ ] §3.1 核心概念從「互連位置」改為「演算法」——開篇即講溫度狀態轉換序列學習
  - [ ] 部署位置降為「可部署在互連匯聚點、MC domain 前端、CXL switch、或軟體/韌體」
  - [ ] 資料溫度評估引擎：三維度描述完整（時間/空間/序列）
  - [ ] 空間維度明確說明可配置為零（MoE 場景不適用空間擴散）
  - [ ] 行為學習表：functional level 描述（學 US5,778,436A），含 predecessor/successor/confidence 欄位、學習時機、替換策略、失效機制
  - [ ] Sizing example：用 256 MoE experts 走一遍具體數字（non-limiting，用 "In some embodiments"）
  - [ ] Markov Prefetcher 差異：聚合+過濾 vs 逐筆記錄、狀態轉換 vs 地址序列、migration 成本不對稱
  - [ ] 通知機制：hint queue (ring buffer) + interrupt/polling，誠實承認與 CHMU 路徑相似
  - [ ] 差異聚焦 hint 內容：CHMU 回報已存取 region / 本案可通知未被存取 region
  - [ ] 軟硬體協作：感知與搬遷解耦，軟體決定是否搬遷
  - [ ] batch serving 交錯問題正面承認 + confidence 過濾機制說明
  - [ ] 系統架構圖：保留集中式+分散式，新增單一 AI 加速器部署圖
  - [ ] per-MC domain ≈ CHMU 位置：誠實承認，差異在演算法不在位置
  - [ ] IRQ = 回報 OS：誠實承認
  - [ ] 移除 eDRAM/scratchpad 從架構圖
  - [ ] Banking 措辭修正：「可降低衝突機率」非「不衝突」
  - [ ] 演算法描述全自然語言（學 AMD），不用 pseudocode
  - [ ] 所有新術語正確使用
  - [ ] ~4 頁

---

## Wave 3

### T004: 修訂 §4 新穎進步簡述

- **Executor:** writer（persistent）
- **Boundary:** §4 新穎進步簡述 only（report lines 280-620 對應內容）
- **Depends:** T003（需要 Ch3 的演算法機制描述 + Markov 差異論述）
- **Input:** 原文 §4 + plan.md Ch4 key messages + research-notes.md（所有 prior art 資訊）
- **Deliverable:** 修訂後的 §4 全文
- **Acceptance:**
  - [ ] 新穎性排序：#1 行為學習表 → #2 多維度統一架構 → #3 部署彈性
  - [ ] 習知技術表新增：NVIDIA GPU Access Counter (US10,361,722)、HBM cache mode (KNL)、Markov Prefetcher (US5,778,436A)
  - [ ] NeoProf 正名為 NeoMem
  - [ ] CXL 版本修正 3.2 → 3.1
  - [ ] CHMU 對比表：刪除「決策延遲」「軟體負擔」虛假差異行，誠實承認通知路徑相似
  - [ ] 對比表聚焦真正差異：序列預測、多維度評估、能否通知未被存取 region
  - [ ] 新增 Markov Prefetcher 對比（最高威脅）：表結構相近但學習對象/觸發條件/應用領域不同
  - [ ] 新增 ML 路線差異（AMD LSTM / Huawei CNN+LSTM）：本案 lightweight table-based，不需 training
  - [ ] 103 防禦論述：聚合+過濾 / 狀態轉換 vs 地址序列 / migration 成本不對稱
  - [ ] 進步性措辭修正：不暗示 cycle 級反應，誠實拆解延遲組成（感知 ns + 通知+決策 μs + 搬遷 varies）
  - [ ] 新增「適用範圍與限制」小節
  - [ ] PE 表以新核心特徵重做（溫度轉換序列學習 + 多維度評估）
  - [ ] 所有新術語正確使用
  - [ ] ~3 頁

---

## Wave 4

### T005: 修訂 §5 專利構想摘要

- **Executor:** writer（persistent）
- **Boundary:** §5 專利構想摘要 only（report lines 400-423 對應內容）
- **Depends:** T003 + T004（濃縮 Ch3 + Ch4）
- **Input:** T003 output（Ch3）+ T004 output（Ch4）+ plan.md Ch5 key messages
- **Deliverable:** 修訂後的 §5 全文
- **Acceptance:**
  - [ ] 核心概念一段式摘要用新術語完整重寫
  - [ ] 不再限定「晶片內互連中」
  - [ ] 核心特徵表：A=行為學習表、B=多維度統一架構、C=部署彈性
  - [ ] 架構特色：「硬體自主感知」改為「自主評估」（承認搬遷需處理器）
  - [ ] 「對互連資料路徑零影響」改為「對記憶體存取路徑零影響」
  - [ ] 分散式部署描述對齊新定位
  - [ ] 所有新術語正確使用，無舊術語殘留
  - [ ] ~1 頁

---

## Final Review（Wave 4 完成後）

- **Executor:** main Claude + verifier 角色
- **Scope:** §1-§5 整體一致性檢查
- **Checklist:**
  - [ ] 術語一致：全文無禁用術語殘留
  - [ ] 邊界一致：§1 定義的邊界與 §2 場景、§3 機制、§4 新穎性都不矛盾
  - [ ] 引用一致：§2 引用 §1 的定義、§3 引用 §2 的缺口、§4 引用 §3 的機制——全部對齊
  - [ ] 敘事連貫：從 §1 到 §5 的論述邏輯順暢
  - [ ] Acceptance criteria 全部通過
  - [ ] 可回應所有已知挑戰（主管、同事、審查員）

---

## Execution Summary

```
Wave 1:  T001 (Ch1) ∥ T002 (Ch2)  → Reconciliation Gate
Wave 2:  T003 (Ch3)               → Gate
Wave 3:  T004 (Ch4)               → Gate
Wave 4:  T005 (Ch5)               → Gate
Final:   Cross-chapter review     → ★ User approve
```

Total: 5 tasks, 4 waves + final review
