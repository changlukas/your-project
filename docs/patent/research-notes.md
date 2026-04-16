# Research Notes for Patent Revision

## 1. 行為學習表描述的適當細節程度

**結論：** 現有描述（report §3.2 lines 107-115）的 zoom level 已經合適。

**參考案例：**

| 來源 | 描述方式 |
|---|---|
| US5,778,436A (Prediction Table) | Functional-parametric：指定 "256K entries, each 16 bits"，indexing 用 "most significant 17 bits"，但 hash function 說 "can be organized using a HASH function" 不指定哪種 |
| Joseph & Grunwald (ISCA 1997) | Functional-only："index is current miss address; each entry has associated next states"。無 bit width，表大小只在 evaluation 出現 |
| US6,976,147 (Stride Confidence) | 行為描述："counter increments on match, decrements on mismatch"，給示範閾值 (>1, >=5, ==7) 但不指定 bit width |
| STeMS (ISCA 2009) | Functional level + evaluation 數字分開 |

**原則：**
- DO specify：entry 包含什麼欄位、lookup 觸發條件、學習時機、替換策略（functional level）
- DO give：一個 preferred embodiment 的具體數字（如 "256 entries"）但標明 non-limiting
- DO NOT specify：hash function、associativity、bit width、FSM state encoding

---

## 2. 方法專利的 §101 防禦案例

### AMD US12,174,742 B2

**Claim 結構：** 20 claims — apparatus (1-10) + method (11-20)

**方法獨立項 (Claim 11) 語言：**
- Preamble: "A method for memory page placement in a computer processing system"
- 不用 "computer-implemented method"
- 步驟包含具體的 ML 架構（LSTM + non-LSTM fallback）
- 最後一步是物理動作："moving pages from first memory to second memory"

**§101 防禦模式：**
1. Preamble 綁定 "computer processing system"（particular machine）
2. 步驟描述具體 ML 架構（非 generic "machine learning"）
3. 結果是物理頁面搬遷（具體技術效果）
4. 依附項加硬體："processing cores" (Claim 18), "LSTM microcontroller" (Claim 19)

### Intel US10,838,647 B2

- 方法獨立項用 "a method of managing application data"
- 步驟提到 "programmable acceleration controller (PAC)" — 綁定硬體元件
- 比 AMD 更硬體導向

### Dell US12,436,813 B2 (CXL memory)

- 方法項用 bare "A method, comprising..."
- 內容提到 CXL switch + workload orchestration

### 通用模式

```
1. Preamble: "A method [for X] in a [processing system/computer system]"
2. 步驟含具體演算法（非 generic）
3. 最後一步是物理動作（page migration）
4. 依附項加硬體作為 §101 fallback
```

---

## 3. Embedding Table 場景量化數據（已查證）

| 論文 | 來源 | 數據 | 狀態 |
|---|---|---|---|
| FAE | VLDB 2022 (arXiv 2103.00686) | Top 6.8% entries 佔 76% 存取；disparity up to 10000x | ✅ Confirmed |
| RecMG | HPCA 2025 (DOI: 10.1109/HPCA61900.2025.00121) | 20% 存取的 reuse distance > 2^20；16 production traces from Meta, 856 embedding tables, 410M+ accesses | ✅ Confirmed |
| Hotline | ISCA 2024 | Embedding ops 佔 training time up to 75% (Criteo Terabyte)；HW: Xeon Silver 4116 + 4x V100 PCIe Gen3 | ✅ Confirmed |
| EMBark | RecSys 2024 (NVIDIA) | Power-law skew α=1.2；1.5x avg / 1.77x peak speedup on DGX H100 | ✅ Confirmed |
| Fleche | EuroSys 2022 | Embedding layer > 60% prediction latency；2.0-5.4x embedding throughput, up to 2.4x e2e inference | ✅ Confirmed |
| LiveUpdate | HPCA 2026 | Hot set drift: "multi-minute staleness" degrades quality → hot sets shift on minutes-to-hours scale | ✅ Confirmed |
| RecMG | HPCA 2025 | TB-scale embedding tables | ✅ Confirmed |

---

## 4. 真實專利的寫作風格研究

### 4.1 Spec 結構（從真實專利中觀察到的模式）

**AMD US12,174,742（LSTM memory page placement）：**
- BACKGROUND：單一段落。開頭講 domain（heterogeneous memory），中間列具體技術（volatile, NVM, stacked DRAM），結尾講 prior art 限制（"inflexible and have difficulty accommodating"）。不引用特定前案專利。
- DETAILED DESCRIPTION：~42 段，順序為：問題重述 → 解法概述 → 系統架構 (FIG.1) → 預測器架構 (FIG.2) → 方法流程 (FIG.3) → LSTM 內部 (FIG.4) → 系統實施例 (FIG.5) → 第二流程 (FIG.6)
- 演算法描述：**全自然語言，無 pseudocode，無數學公式**。K-means、distance measure、LSTM gates 都用文字描述。
- 實施例：用 "In some embodiments"（非 "In one embodiment"）。混合抽象變數 + 具體數字："E number of recent epochs" → "one second, 100 milliseconds, 10 milliseconds..."
- 6 figures：block diagrams (3) + flowcharts (2) + LSTM architecture (1)
- 同一發明描述三次：overview → system architecture → algorithm internals（漸進式深入）

**Intel US12,443,537（page hotness metadata）：**
- BACKGROUND：4-5 段。逐步聚焦：disaggregation 趨勢 → 延遲差異 (~100ns) → tiered memory → hot/cold detection 挑戰
- 術語：用 "hot pages" / "cold pages" / "page hotness/coldness" / "relative page hotness score"。**不用 "temperature"**
- CLAIM 結構：經典三件套 — Method (Claim 1) + Apparatus (Claim 10) + CRM (Claim 16)
- 方法 Claim 1 preamble："A method implemented with a compute platform..."
- 軟硬體關係：軟體層發明但 Claim 錨定硬體平台 — apparatus claim 用 "wherein execution of the software enables the compute platform to..."
- 11 figures：architecture + state diagrams + filtering concept + data structure + flowchart

**Intel US10,838,647（adaptive data migration）：**
- BACKGROUND：2 短段，非常 generic
- DETAILED DESCRIPTION：問題先行 — 8+ 段問題動機之後才進解法
- CLAIM：三件套，更硬體導向："programmable acceleration controller (PAC)", "telemetry interface"
- 術語：用 "application data performance metrics" 和 "hotspots"，不用 hot/cold pages

### 4.2 Claim 動詞與語言模式

**AMD Claim 11 動詞：** determining, identifying, predicting, moving
**條件觸發：** "responsive to [condition]"（不用 if/when）
**依附項動詞：** grouping, selecting, sorting, training, adjusting

**Intel Claim 1 (US12,443,537) 模式：**
```
"A method implemented with a compute platform, the method comprising:
  populating...;
  filtering...;
  updating...;
  determining..."
```

**通用觀察：**
- 獨立項用 gerund (-ing) 動詞
- 條件用 "responsive to" 或 "based on"
- 最後一步通常是物理動作（moving, migrating, transferring）
- Preamble 綁定 "processing system" / "compute platform" / "computer system"

### 4.3 Markov Prefetcher US5,778,436A — 完整 Claim 原文

**Claim 1（裝置項）：**
> "A predictive cache memory subsystem for a data processing system including a main memory, said predictive cache memory subsystem comprising: cache memory means for storing therein data blocks from said main memory; identifying means, responsive to an access request to said main memory for a first main memory data block which results from a cache miss...for identifying a second main memory data block which was accessed following an immediately preceding access request to said main memory for said first main memory data block...and storing means, responsive to said identifying means, for storing said second main memory data block in said cache memory means if said second main memory data block is not already stored in said cache memory means."

**Claim 10（裝置項，含 prediction table）：**
> "...a prediction table which stores therein identifications of a plurality of succeeding main memory data blocks, each of which was accessed following an access request to a corresponding one of a plurality of preceding main memory data blocks..."

**Claim 16（方法項）：**
> "A predictive cache memory method for a data processing system including main memory and cache memory...comprising the steps of: identifying a second main memory data block which was accessed following an immediately preceding access request to said main memory for a first main memory data block, in response to an access request...which results from a cache miss...and storing said second main memory data block in said cache memory..."

**Prediction Table 結構描述：**
> "Prediction Table 210 may be organized as 256K×16×2, that is 256K two-word entries, with each word being 16 bits wide."

**學習機制描述：**
> "the Access Prediction Unit 200 continuously monitors main memory requests via main memory bus 75. It records the main memory row address...for the access following the current access, and stores it in the Prediction Table entry of the current block"

**更新機制：**
> "If the next access request is for the second main memory data block, the prediction was correct and the Prediction Table need not be updated. However, if the next access request is for a third data block, an identification of the third data block is stored in the Prediction Table as the identification corresponding to the first data block."

### 4.4 Micron US12,449,978（部分資訊）

- 裝置/Host 互動模式：Memory device 累積計數 → Host 發 request 取回數值 → Host 用 hash + minimum value 評估分佈 → Host 決定資料放置
- 術語：用 "hot data" / "cold data"，明確定義 "relatively frequently-accessed data (e.g., 'hot' data)"
- Claim 結構：apparatus + method，兩個獨立項

### 4.5 NVIDIA US10,361,722（從 research agent 資訊）

- 機制：per-page access counter → programmable threshold → 通知 GPU driver → driver 決定是否經 Page Migration Engine 搬遷
- MIMC (migration toward GPU) / MOMC (migration toward CPU) 兩種 counter
- 通知方式：類似 replayable page fault interrupt
- 延續案：US10,866,900 B2

---

## 5. 本案 Claim 應學習的模式

根據上述 research，本案方法項應該：

```
Preamble 模式（學 AMD）：
  "A method for data placement in a data processing system
   having a plurality of memory tiers, the method comprising:"

步驟動詞模式（學 AMD + Intel）：
  obtaining...; maintaining...; detecting...;
  recording...; confirming...; updating...;
  generating...

條件觸發（學 AMD）：
  "responsive to detecting a temperature transition event..."

最後一步物理動作（學 AMD）：
  "generating a placement recommendation indicating the memory region
   should be migrated to a faster or slower memory tier"
  （注意：不是 "migrating" 而是 "generating recommendation"，
   因為本案感知與搬遷解耦）

依附項加硬體（學 Intel US12,443,537）：
  "wherein the method is implemented by a hardware circuit
   disposed on a memory access path of the data processing system"

說明書結構（學 AMD）：
  1. BACKGROUND：1-2 段，問題+prior art 限制
  2. SUMMARY：核心方法概述
  3. DETAILED DESCRIPTION：
     - 系統架構 (FIG.1)
     - 演算法概述 → 多維度評估 (FIG.2)
     - 行為學習表詳細機制 (FIG.3)
     - 方法流程 (FIG.4 flowchart)
     - 實施例 1: MoE (FIG.5)
     - 實施例 2: Embedding Table (FIG.6)
  4. CLAIMS

術語選擇：
  → Intel 用 "hot/cold pages"，AMD 用 "page accesses"
  → 本案用 "temperature score"（與標題一致）
  → 但 Claim 中避免隱喻，用 "access activity metric" 或直接用 "temperature score"
     搭配說明書中的定義
```
