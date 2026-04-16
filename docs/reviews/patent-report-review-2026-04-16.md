# Review Report: 硬體資料溫度感知與記憶體層級放置控制

**Review date:** 2026-04-16
**Reviewed document:** `hardware_hot_cold_sensing_patent_report.md`
**Review method:** review-document workflow (section-by-section, sequential)

---

## Scope

**評估重點（使用者定義）：**
1. 現有解決方案與本案的對比是否成立
2. 本案的邊界在哪
3. 實施例的合適性——到底要應用在哪些場景

**外部回饋（已納入）：**
- 主管回饋（2026-04-08 報告後）：「非常模糊」「系統層級已在管」「實施例不清楚」
- 資深同事回饋：「記憶體階層本身就已經解決了這件事」
- 使用者與 AI 的事後討論（`review.md`，2026-04-13）

---

## Per-Section Results

### Section 1: 背景 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 近端/遠端邊界混淆 | Major | on-chip SRAM/scratchpad 與 HBM 混為「近端」，但本案 region 粒度（64KB+）不管 SRAM 層 |
| Intel Optane 已停產 | Minor | review 備忘已標記，未執行 |
| Cache 替換策略論述過絕對 | Minor | 部分架構支援 cache hint，需軟化 |
| 背景章未預告 chiplet 場景 | Minor | 與 §6 實施例不對齊 |

### Section 2: 要解決什麼問題 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 現有機制表缺三個關鍵對手 | Major | 缺 HBM cache mode、CXL CHMU（此處才出現太晚）、NVIDIA GPU Access Counter |
| 核心主張無量化佐證 | Major | 「瓶頸在感知到決策」無數字（OS 秒級 vs AI workload ms 級） |
| 問題場景舉例不當 | Minor | 用 LLM weights（軟體已解決）而非 MoE / embedding table |
| §2.2 與 §3.1 重複 | Minor | review 備忘已標記 |

### Section 3a: 核心概念 + 感知計算單元 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 行為學習表在 batch serving 下的交錯問題 | Major | 多 request 交錯會學到虛假 correlation，未討論 confidence 如何應對 |
| 缺 sizing example | Minor | 主管「模糊」回饋在此仍未解決 |
| 空間維度在 MoE 場景無效 | Minor | 未說明可配置為零 |
| Banking 斷言過度 | Minor | 「不與同組衝突」應改為「可降低衝突機率」 |

### Section 3b: 系統架構 + 軟硬體協作 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 全域可見性在 mesh NoC 下不成立 | Major | 現代 AI 加速器幾乎都是 mesh，per-MC domain 才是主要部署 |
| IRQ+CPU 路徑延遲未討論 | Major | 端到端是 μs 級非 cycle 級，文件暗示「硬體速度」 |
| 缺最主流的單一加速器部署圖 | Minor | 只有集中式和分散式，缺 AI accelerator + HBM 場景 |
| 架構圖含 eDRAM/scratchpad | Minor | 延續 §1 邊界問題 |

**PIVOT 1：** 使用者指出 per-MC domain 位置與 CHMU/NeoMem 接近 → 核心差異化從「位置」轉向「演算法」

**PIVOT 2：** 使用者指出 IRQ 通知等同回報 OS → 通知機制不是差異化，hint 內容（預測 vs 回報）才是

### Section 4: 新穎進步簡述 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 對比表多處虛假差異 | Major | 決策延遲、軟體負擔在 per-MC domain + IRQ 前提下不成立 |
| 新穎性排序錯誤 | Major | 互連位置排第一但最弱，行為學習表排第三但最強 |
| 缺 NVIDIA GPU Access Counter | Minor | US10,361,722 未列 |
| 缺 HBM cache mode | Minor | 同事已挑戰但未回應 |
| NeoProf 未正名 NeoMem | Minor | review 備忘已標記 |

### Section 5: 專利構想摘要 — FAIL（需全面改寫）

所有舊定位問題的濃縮。核心概念、核心特徵排序、架構特色措辭全需對齊新框架。

### Section 6: 實施例及應用例 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 實施例 1 LLM+LoRA 不展示行為學習表 | Major | 展示的是 QoS 配置，CHMU+軟體也做得到 |
| 實施例 2 MoE 缺軟體對比和量化數據 | Major | 最強場景但敘述不足，無 concrete walkthrough |
| 缺推薦系統 Embedding Table 實施例 | Major | review.md 已分析為 ★★★ 場景，有充分文獻 |
| 實施例 3 Chiplet 不展示核心差異化 | Minor | 無序列預測，無文獻佐證 |

### Section 7: 前案技術檢索說明 — FAIL

| Issue | 嚴重度 | 說明 |
|---|---|---|
| 缺 Markov Prefetcher 對比 | Critical | predecessor/successor/confidence 結構與行為學習表幾乎相同，103 風險極高 |
| 缺 NVIDIA GPU Access Counter | Critical | US10,361,722 是直接 prior art |
| CXL 版本錯誤 | Major | CHMU 是 CXL 3.1 引入，非 3.2 |
| PE 以「互連位置」為核心特徵 | Major | 應改為以行為學習表和多維度評估為核心 |

**Research 發現：**
- Markov Prefetcher (ISCA 1997) / US5,778,436A 的表結構與行為學習表幾乎一模一樣
- 差異在：地址序列 vs 溫度狀態轉換序列、逐筆記錄 vs 聚合+過濾
- EARTH (ASPLOS 2026) 是 MoE-specific 硬體 prefetch，非通用序列學習
- ArtMem (ISCA '25) 用 RL 調整 migration threshold，不學序列

### Section 8: Claim 規劃 — FAIL（需全面重寫）

整套 Claim 硬體導向，行為學習表在依附項，方法項限定互連。

**PIVOT 3：** 使用者確認走演算法/方法路線，不走純硬體。原因：(1) 硬體面積代價大 (2) 真正新穎性在演算法 (3) 軟體實作也應被保護。

### Section 9: §101 風險評估 — FAIL（需以新框架重寫）

防禦策略全依賴硬體元件，演算法路線需改為 particular machine + technical effect + non-conventional step。

### Section 10: 侵權判定與推廣 — FAIL（需以新框架重寫）

偵測方法全基於硬體 Claim，演算法路線需改為效能測試觀察預測行為 + SDK/driver source code。

---

## Problem Consolidation

所有 issues 收斂為三個根本問題：

### 根本問題 1：核心定位錯誤

文件把「硬體 + 互連位置」當核心差異化，但：
- 互連位置在 mesh NoC 下不成立（per-MC domain ≈ CHMU 位置）
- IRQ 通知等同回報 OS（通知機制不是差異）
- 硬體的個別元件都有 prior art

**真正的差異化是演算法**：溫度狀態轉換序列學習。這在硬體和軟體空間都是空白（research 確認）。

影響 Section：1, 2, 3, 4, 5, 7, 8, 9, 10（幾乎全部）

### 根本問題 2：缺「軟體為什麼不夠」的完整論證

主管的核心質疑未被回應。現有方案的列舉缺三個關鍵對手（HBM cache mode、CHMU、GPU Access Counter），缺量化數據，缺「軟體嘗試過但做不好」的證據鏈。

影響 Section：2, 4, 6, 7

### 根本問題 3：實施例不展示核心差異化

三個實施例中只有 MoE 展示了行為學習表，且缺 concrete walkthrough。最強的第二場景（Embedding Table）沒有實施例。最弱的場景（LLM+LoRA、Chiplet）反而佔了兩個實施例。

影響 Section：6

---

## Revision Plan

### Phase 1 (Week 1): 核心定位重設

- 確立新核心：溫度狀態轉換序列學習演算法
- Claim 1 重寫：方法獨立項，序列學習在獨立項中
- 新術語全面套用：溫度分數、資料溫度評估引擎、多維度存取行為評估
- 通知機制對齊 CHMU 用語（hint queue / ring buffer / interrupt+polling）

### Phase 2 (Week 2): 前案補強 + 實施例重建

- 新增 Markov Prefetcher 對比 + 103 防禦策略
- 新增 NVIDIA GPU Access Counter、HBM cache mode、EARTH、ArtMem
- MoE 實施例補軟體方案對比 + 量化數據 + concrete walkthrough
- 新增 Embedding Table 實施例
- LLM+LoRA 和 Chiplet 降為推廣應用

### Phase 3 (Week 3): 收尾

- §101 策略以新框架重寫
- 侵權偵測改為效能測試 + SDK/driver
- 行為學習表補充適當實作描述
- 誠實修正（IRQ=回報OS、per-MC≈CHMU位置、適用範圍與限制）
- 術語統一、邊界修正、CXL 版本修正

---

## PIVOT Log

| # | 觸發 | 新方向 | 影響範圍 |
|---|------|--------|---------|
| 1 | 使用者：「per-MC domain 位置跟 CHMU 一樣」| 核心差異化從位置轉向演算法 | §3, §4, §5, §7, §8 |
| 2 | 使用者：「IRQ 也是回報 OS」| 通知機制不是差異化，hint 內容才是 | §3.4, §4 對比表 |
| 3 | 使用者：「不一定要硬體，也可以軟體演算法」+ 確認走演算法路線 | 從硬體專利轉為方法專利 | §8 Claim 全面重寫, §9, §10 |

---

## Independent Research Findings

### 已查證事實

| 項目 | 結果 |
|---|---|
| CHMU 版本 | CXL 3.1 引入（非 3.2）|
| NVIDIA GPU Access Counter | US10,361,722 B2 (2019), per-page 計數+閾值+通知 driver |
| Markov Prefetcher | ISCA 1997, predecessor/successor/confidence 結構已存在 |
| MoBiLE 論文 | Confirmed：prefetch 訓練開銷大、fine-grained 效果下降 |
| DynaExq 年份 | 2025 非 2026 |
| DeepSeek-R1 671GB | 數學正確但有誤導性（MoE sparse activation ~37B/token）|
| EARTH (ASPLOS 2026) | MoE-specific entropy-aware prefetch，非通用序列學習 |
| ArtMem (ISCA 2025) | RL 調整 migration threshold，不學 region 間序列 |

### 空白確認

| 空間 | 溫度狀態轉換序列學習是否被佔據 |
|---|---|
| 硬體 | **空白** — 所有硬體方案（CHMU, NeoMem, GPU Access Counter, Intel Flat Memory Mode）均為純計數，無序列預測 |
| 軟體/演算法 | **空白** — AutoNUMA, TPP, MEMTIS, Chrono, Colloid, M5, PET 均為 reactive；ArtMem (RL) 學的是閾值不是序列 |
| ML 模型 | **不同路線** — Huawei (CNN+LSTM), AMD (LSTM), RecMG (LSTM) 均學 address/frequency，非溫度狀態轉換 |
| 專利 | **空白** — 無專利 claim 溫度狀態轉換序列學習方法用於 memory tiering |

### 103 核駁最高風險

Markov Prefetcher (US5,778,436A) + 任何 memory tiering prior art 的組合。
防禦要點：聚合+過濾（非逐筆記錄）、狀態轉換序列（非地址序列）、migration 成本不對稱性。
