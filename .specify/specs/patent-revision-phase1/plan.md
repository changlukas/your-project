# Document Plan: Patent Concept Report Revision — Phase 1

## Terminology

| Term (EN) | Term (中文) | Definition | 取代舊用語 |
|---|---|---|---|
| temperature score | 溫度分數 | 各 memory region 的複合存取活躍度指標，由多維度評估更新 | 冷熱分數 |
| data temperature evaluation engine | 資料溫度評估引擎 | 整合時間/空間/序列三維度評估的核心運算單元 | 冷熱感知計算單元 |
| multi-dimensional access behavior evaluation | 多維度存取行為評估 | 時間+空間+序列三維度的統一評估方法 | 三種策略/三策略合成分數 |
| temporal dimension | 時間維度 | 追蹤存取強度 + 週期性衰減 | 時間策略 |
| spatial dimension | 空間維度 | 冷轉熱時對鄰近 region 加分 | 空間策略 |
| sequential dimension | 序列維度 | 行為學習表的轉換序列學習與預測 | 預測性策略 |
| behavior learning table | 行為學習表 | 記錄溫度轉換事件的前驅/後繼對應關係並自主學習規律 | （保留，無變更）|
| temperature transition event | 溫度轉換事件 | 一 region 的溫度分數從低於 promote 閾值上升至高於該閾值 | 冷轉熱事件 |
| hint queue | hint queue | Ring buffer 結構，存放 placement hint entry，支援 interrupt/polling | placement hint + IRQ |
| flat mode | Flat mode | HBM 與 DDR 為獨立可定址記憶體空間，軟體決定資料放置 | （新增）|
| cache mode | Cache mode | HBM 作為 DDR 的 last-level cache，硬體自動管理放置 | （新增）|
| placement recommendation | 放置建議 | 感知單元/演算法產出的搬遷方向建議（promote / demote） | placement hint（Claim 用語保留 hint）|

**禁用術語：**
- ❌ 「三種策略」→ 用「多維度存取行為評估」或「時間/空間/序列三個維度」
- ❌ 「冷熱分數」→ 用「溫度分數」
- ❌ 「冷轉熱」→ 用「溫度轉換事件」（或 "cold-to-hot transition" 在需要直覺解釋時）
- ❌ 「透過 IRQ 通知處理器」→ 用「寫入 hint queue，以 interrupt 或 polling 通知」
- ❌ 「全域可見性」→ 不再作為核心賣點使用
- ❌ Intel Optane（已停產，不應使用可追溯至特定 vendor 的術語）

---

## Chapters

### Ch1: 背景（§1）

- **Purpose:** 建立異質記憶體架構的 context，引導讀者理解為什麼需要搬遷決策輔助
- **Key messages:**
  1. 異質記憶體架構已普遍（HBM / DDR / CXL），各層級延遲差異大
  2. **Cache mode vs Flat mode 的差異**（新增，核心）：cache mode 由硬體管理，flat mode 需軟體管理。業界越走越多 flat mode（H100、MI300X、CXL memory 天然 flat）
  3. Cache mode 的限制：tag overhead、cacheline 粒度、無預測、thrashing
  4. Flat mode 下的管理空白：cache hierarchy 管 cacheline 粒度，OS 管 page 粒度但太慢，中間缺一個 region 粒度的即時評估機制
  5. 邊界劃線：本案管 flat mode 下 DRAM-class 層級之間，不管 cache 內部也不管 SRAM/scratchpad
- **Length:** ~1.5 頁
- **Depends on:** 無
- **References:** H100/MI300X spec, Intel KNL MCDRAM cache mode 作為 cache mode 代表
- **修訂重點 vs 原文：** 移除 SRAM/scratchpad 歸類、移除 Intel Optane、新增 cache mode vs flat mode 段落、收斂邊界

---

### Ch2: 問題定義（§2）

- **Purpose:** 精確描述問題、列舉所有現有方案及其限制、定義適用場景
- **Key messages:**
  1. 問題核心：在 flat mode 下，如何即時判定各 region 的溫度狀態並在適當時機建議搬遷
  2. **現有機制完整列表**（擴充為 6 類）：
     - 軟體配置（numactl）→ 靜態
     - Fault 驅動（CUDA UM）→ 被動
     - OS 掃描（AutoNUMA/TPP）→ 秒級，太慢
     - HBM cache mode → cacheline 粒度，無預測，tag overhead
     - GPU access counter（NVIDIA Volta+）→ per-page 計數，無預測，單端可見
     - CXL 3.1 CHMU → device 端計數，無全域可見，無預測
  3. **所有方案的共同缺口**：無預測能力（無法通知尚未被存取的 region）
  4. 量化佐證：OS 掃描 ~10-60 秒 vs AI workload pattern 變化 ms 級
  5. **適用場景正面定義**（新增）：MoE（★★★）、Embedding table（★★★）、Multi-model serving（★★）
  6. **不適用場景正面定義**（新增）：LLM layer-by-layer、KV cache、一般伺服器 NUMA
- **Length:** ~2 頁
- **Depends on:** Ch1（引用 cache mode vs flat mode 定義）
- **References:** HOBBIT (2024), MoBiLE (2025), FAE (VLDB 2022), RecMG (HPCA 2025)
- **修訂重點 vs 原文：** 現有機制表從 3 類擴充為 6 類、新增量化數據、新增適用/不適用場景定義、CXL 版本修正 3.2→3.1

---

### Ch3: 解決方法（§3）

- **Purpose:** 描述演算法的完整機制，不綁定硬體或軟體
- **Key messages:**
  1. **核心概念重設**（改寫 §3.1）：本案核心是溫度狀態轉換序列學習演算法。可部署在任何能觀察目標位址範圍存取流量的節點——互連匯聚點、MC domain 前端、CXL switch、或以軟體/韌體實作
  2. **資料溫度評估引擎**（改寫 §3.2）：
     - 時間維度：存取累加 + 週期性右移衰減
     - 空間維度：溫度轉換事件觸發鄰近 region 加分（可配置為零）
     - 序列維度：行為學習表從溫度轉換序列中學習規律
  3. **行為學習表詳細描述**（補強）：
     - 表結構：predecessor / successor / confidence counter（functional level，學 US5,778,436A）
     - 學習機制：溫度轉換事件觸發記錄前驅/後繼，重複觀測累積 confidence
     - 預測機制：命中已確認規律時對後繼 region 更新溫度分數
     - 替換策略：confidence 最低者優先替換
     - 失效機制：confidence 週期性遞減
     - Sizing example：追蹤 256 MoE experts 的具體數字（non-limiting）
  4. **「聚合+過濾」vs Markov Prefetcher 的差異**（新增，為 103 防禦鋪墊）：
     - 本案不逐筆記錄每次存取，而是聚合為 region 溫度分數後，只在溫度轉換事件時才學習
     - 信噪比高得多（溫度轉換事件每秒數十次 vs cache miss 每秒百萬次）
  5. **通知機制**（改寫 §3.4）：hint queue (ring buffer) + interrupt/polling，誠實承認與 CHMU 通知路徑相似，差異在 hint 內容（預測 vs 回報）
  6. **軟硬體協作**（改寫 §3.4）：感知與搬遷解耦。軟體決定是否採納建議
  7. **batch serving 下的交錯問題**（新增）：正面承認限制 + confidence 機制如何應對
  8. 系統架構圖保留但補充最主流的單一加速器部署圖
- **Length:** ~4 頁（最長章節）
- **Depends on:** Ch1（flat mode 定義）、Ch2（現有方案缺口 = 無預測）
- **References:** US5,778,436A (Markov Prefetcher), US6,976,147 (Stride Confidence), CHMU spec
- **修訂重點 vs 原文：** §3.1 從「互連位置」改為「演算法」、術語全面替換、行為學習表補強、新增 Markov 差異論述、通知機制對齊 CHMU、新增 batch serving 限制討論、移除 eDRAM/scratchpad

---

### Ch4: 新穎進步簡述（§4）

- **Purpose:** 對比本案與所有 prior art 的差異，建立新穎性與進步性論述
- **Key messages:**
  1. **新穎性重排**：
     - 第一：溫度狀態轉換序列的硬體/軟體自主學習（所有 prior art 都沒有）
     - 第二：多維度評估的統一溫度分數架構
     - 第三：部署位置的彈性（從「唯一正確位置」改為「適應不同拓撲」）
  2. **習知技術表擴充**（新增 3 項）：
     - NVIDIA GPU Access Counter (Volta+, US10,361,722)
     - HBM cache mode (Intel KNL MCDRAM)
     - Markov Prefetcher (ISCA 1997, US5,778,436A)——最高威脅對比
  3. **CHMU 對比表誠實修正**：
     - 刪除「決策延遲」「軟體負擔」虛假差異
     - 誠實承認通知路徑相似
     - 聚焦真正差異：序列預測能力、多維度評估、能否通知未被存取的 region
  4. **與 ML 路線的差異**（新增）：AMD LSTM / Huawei CNN+LSTM / RecMG — 本案走 lightweight table-based，不需 training data
  5. **103 防禦論述**（新增 Markov Prefetcher 差異）：聚合+過濾、狀態轉換 vs 地址序列、migration 成本不對稱
  6. **進步性修正措辭**：不再暗示 cycle 級反應，誠實拆解延遲組成
  7. **適用範圍與限制**（新增小節）：正面定義適用/不適用條件
- **Length:** ~3 頁
- **Depends on:** Ch2（現有機制表）、Ch3（演算法機制 + Markov 差異）
- **References:** CXL 3.1 spec, US10,361,722, US5,778,436A, US12,174,742, US12,379,861
- **修訂重點 vs 原文：** 新穎性排序翻轉、對比表大幅修正、新增 3 個 prior art、新增 103 防禦、新增適用範圍

---

### Ch5: 專利構想摘要（§5）

- **Purpose:** 全文 executive summary，對齊新定位
- **Key messages:**
  1. 核心概念一段式摘要（用新術語重寫）
  2. 核心特徵表：A=行為學習表（第一）、B=多維度統一架構（第二）、C=部署彈性（第三）
  3. 架構特色列表對齊新定位
- **Length:** ~1 頁
- **Depends on:** Ch3（機制細節）、Ch4（新穎性定位）
- **References:** 無額外
- **修訂重點 vs 原文：** 全面改寫。核心特徵 A/C 互換，所有術語替換，架構特色措辭修正

---

## Chapter Dependencies

```
Ch1 背景（獨立）
  ↓
Ch2 問題定義（引用 Ch1 的 cache mode vs flat mode）
  ↓
Ch3 解決方法（引用 Ch2 的「共同缺口=無預測」）
  ↓
Ch4 新穎進步（引用 Ch3 的演算法機制 + Markov 差異）
  ↓
Ch5 構想摘要（濃縮 Ch3 + Ch4）
```

內容上全串行依賴，但透過 interface contract 可部分並行。

## Wave Plan

**Wave 1:** Ch1 背景 ∥ Ch2 問題定義（並行，Ch2 引用 Ch1 概念時使用 interface contract placeholder，完成後 reconciliation）
**Wave 2:** Ch3 解決方法（需要 Ch1 + Ch2 output）
**Wave 3:** Ch4 新穎進步（需要 Ch3 output）
**Wave 4:** Ch5 構想摘要（需要 Ch3 + Ch4 output）

每個 Wave 完成後 Gate check 再進下一個。Interface contract 定義見 tasks.md。
