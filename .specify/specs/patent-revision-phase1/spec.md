# Document Spec: Patent Concept Report Revision — Phase 1

## Purpose

將專利概念報告（`hardware_hot_cold_sensing_patent_report.md`）的核心定位從「硬體+互連位置」
重設為「演算法/方法」核心。修訂後的文件需能：

1. 回應所有已知的技術挑戰（主管、資深同事、未來審查員）
2. 為後續 Phase 2（實施例重建）和 Phase 3（Claim + §101）提供穩固基礎

## Target Audience

- **主要讀者：** 作者本人（整理為 PPT 和代理人版本的基礎）
- **衍生版本 A：** 內部報告 PPT — 需能回應主管/同事挑戰
- **衍生版本 B：** 專利代理人交接稿 — 需有足夠技術細節供律師撰寫正式申請

先完成 A 版定稿，再轉 B 版。

## Scope

### In（Phase 1 修訂範圍）

| Section | 修訂內容 |
|---|---|
| §1 背景 | 修正邊界（移除 SRAM/scratchpad）、新增 cache mode vs flat mode 解釋、補 HBM cache mode 為何不足 |
| §2 問題定義 | 補全現有機制表（+CHMU, +GPU Access Counter, +HBM cache mode）、加量化數據（OS 掃描秒級 vs AI workload ms 級）、明確定義適用/不適用場景 |
| §3 解決方法 | 核心概念從「互連位置」改為「演算法」、術語全面替換（溫度分數/資料溫度評估引擎/多維度存取行為評估）、行為學習表補充實作描述（functional level, 學 US5,778,436A 風格）、補 sizing example、通知機制改為 hint queue + interrupt/polling（對齊 CHMU 用語）、誠實承認 IRQ=回報OS、per-MC≈CHMU 位置 |
| §4 新穎進步 | 新穎性重排（行為學習表第一）、對比表誠實修正（刪除虛假差異）、新增 Markov Prefetcher 對比 + 103 防禦論述、新增 NVIDIA Access Counter + HBM cache mode 到習知技術表 |
| §5 構想摘要 | 全面改寫對齊新定位 |

### Out（不在 Phase 1）

- §6 實施例重建（Phase 2）
- §7 前案檢索重做（Phase 2）
- §8 Claim 重寫（Phase 3）
- §9 §101 更新（Phase 3）
- §10 侵權判定更新（Phase 3）

## 邊界定義（核心修訂內容之一）

文件中需明確建立的邊界：

### 本案管什麼

在 **flat mode**（HBM 與 DDR 為獨立可定址記憶體空間，軟體決定資料放置）下，
DRAM-class 記憶體層級（HBM ↔ DDR ↔ CXL memory）之間的**搬遷決策輔助**。

適用場景需同時滿足：
- 存取 pattern 動態，runtime 才決定（非 compile-time 已知）
- 歷史冷熱轉換序列有統計上的重複規律可學習
- 資料量超過近端記憶體容量
- 演算法本身不綁定硬體或軟體實作

### 本案不管什麼

- **Cache hierarchy 內部**：cacheline 粒度，硬體 LRU 已處理
- **On-chip SRAM / scratchpad**：compiler 或硬體管理
- **HBM cache mode**：HBM 當作 DDR 的 last-level cache，硬體自動管理
  - 需在文件中明確解釋 cache mode vs flat mode 差異
  - 說明 cache mode 的限制（tag overhead、cacheline 粒度 thrashing、無預測能力）
  - 說明為什麼業界越來越走 flat mode
- **靜態/compile-time 可知的存取序列**：如 LLM 逐層推理，軟體 scheduler 已足夠
- **線性增長 pattern**：如 KV cache，完全可預測不需學習
- **搬遷的決策與執行**：本案只到「產生放置建議」，軟體決定是否及如何搬遷

### 核心適用場景（需在 §2 明確列出）

| 場景 | 適用原因 | 強度 |
|---|---|---|
| MoE expert routing | 每 token 動態選 expert，Gating 無跨 token 記憶，有統計規律 | ★★★ |
| 推薦系統 embedding table | 每 request 動態 lookup，hot set 隨 trending 漂移，有共現規律 | ★★★ |
| Multi-model serving | 流量動態決定載入哪個模型，有時段規律 | ★★ |

## References

- `hardware_hot_cold_sensing_patent_report.md`（原始概念報告）
- `review.md`（主管回饋 + AI 討論）
- `your-project/docs/reviews/patent-report-review-2026-04-16.md`（完整 review report）
- `research-notes.md`（前案研究 + 專利寫作風格研究）

## Writing Style（從 research 中學到的）

- 說明書結構學 AMD US12,174,742：問題 → 概述 → 架構 → 演算法 → 流程 → 實施例
- 演算法描述全自然語言，不用 pseudocode（學 AMD）
- 實施例用 "In some embodiments" + 具體數字標明 non-limiting（學 AMD）
- 先描述三次同一發明，漸進式深入：overview → architecture → internals（學 AMD）
- 術語統一：溫度分數 / 資料溫度評估引擎 / 多維度存取行為評估 / 時間維度 / 空間維度 / 序列維度

## Acceptance Criteria

- [ ] 任何可預見的技術挑戰（主管「模糊」「系統層已在管」、同事「記憶體階層已解決」、審查員 103/101）都有站得住腳的回答
- [ ] 邊界、適用場景、不適用場景明確到可以一頁 PPT 說清楚
- [ ] cache mode vs flat mode 差異有清楚解釋
- [ ] 新術語一致使用，無舊術語殘留
- [ ] 行為學習表描述達到「工程師看得懂怎麼做但不鎖死唯一做法」的 zoom level
- [ ] 對比表中無虛假差異（IRQ 通知、位置優勢等已誠實處理）
- [ ] Markov Prefetcher 的差異有明確、可防禦的論述
