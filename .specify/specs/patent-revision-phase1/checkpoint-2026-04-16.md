# Checkpoint: Patent Revision Phase 1

**Date:** 2026-04-16
**Branch:** `feat/doc-patent-revision-phase1`
**Last commit:** 978b3e5

---

## 完成的工作

### Review（Phase 0）
- 10 個 Section 逐節評估完成（review report 在 `feat/review-document-skill` branch）
- 3 次 PIVOT：位置→演算法、IRQ=回報OS、走方法項非硬體
- 獨立 research：Markov Prefetcher、NVIDIA Access Counter、CHMU、MoE 文獻、空白確認
- 確認核心新穎性 = 溫度狀態轉換序列學習演算法（硬體+軟體空間均空白）

### Phase 1 第一輪（已完成但需重寫）
- spec.md / plan.md / tasks.md 產出
- §1-§5 第一版修訂（4 waves，含 Wave 1 並行 + interface contract）
- 用戶 review 後發現結構性問題：文件像四不像，讀不懂

### 結構分析
- Fresh eyes agent review 完成：10 點殘酷回饋
- 主管專利 P51140026 風格分析完成
- 新結構方向確定：問題→解法→背景（非背景→問題→解法）

---

## 待做的工作（下次 session 接續）

### §1-§3 重寫（新結構）

**新 §1：要解決什麼問題**
- 1 段 + 1 張圖（學主管風格）
- 痛點：AI workload 的資料搬遷在 critical path 上等待，現有方案只能事後回報不能事前預測
- 需要 research：如何讓非專業讀者秒懂「預測搬遷 vs 反應式搬遷」的差異
- 圖：時間軸對比（沒有預測 vs 有預測）

**新 §2：預計解決方案**
- 1 段 + 演算法流程圖
- 核心一句話：溫度狀態轉換序列學習演算法
- 流程圖已有（Step 1-5），需移到這裡作為核心圖

**新 §3：設計背景**
- 原 §1 砍 60%
- Flat mode vs cache mode：2-3 句（非 20 行）
- 邊界定義：本案管什麼/不管什麼（1 段）

### §4 解決方法詳述
- **需要和用戶重新盤設計想法**，不是直接修舊版
- 待用戶確認方向後才開始

### 規則
- 每一段 research 先行再寫
- 寫完用 read agent 驗證
- 嚴格遵守 CLAUDE.md Critical Rules
- 不寫無 research 支撐的宣稱（如「三種典型部署方式」）

---

## 已識別的問題（需在重寫中解決）

1. 背景太長，問題被埋在最後
2. §2 在問題定義章做了 mini literature review
3. §2.3 適用/不適用場景放太早（還沒看到解法）
4. §3 混了演算法、部署、edge case、硬體
5. §3.5 部署方式無 research 支撐且打斷演算法描述
6. 演算法流程圖放在硬體實作小節而非核心概念
7. 標題「硬體資料溫度感知」與軟體演算法定位矛盾
8. 「感知單元」和「評估引擎」混用
9. §4 prior art 比較表太大，新穎性被淹沒
10. 103 防禦和 PE 表打斷概念報告敘事

## 關鍵決策記錄

| 決策 | 日期 | 理由 |
|------|------|------|
| 核心定位 = 演算法非硬體 | 2026-04-16 | per-MC≈CHMU位置、IRQ=回報OS、個別硬體元件都有 prior art |
| 走方法項 Claim 為主 | 2026-04-16 | 軟體+硬體空間都空白，方法項保護範圍最寬 |
| hotlist 對齊 CXL 用語 | 2026-04-16 | 用戶要求，通知機制是通用解 |
| 問題→解法→背景 敘事順序 | 2026-04-16 | 學主管專利風格，fresh eyes review 確認背景先行不 work |
| §4 解決方法需重新盤設計 | 2026-04-16 | 用戶要求，不是修舊版而是重新想 |

## 相關 Branch

| Branch | 內容 |
|--------|------|
| `feat/doc-patent-revision-phase1` | 本次修訂（當前 branch）|
| `feat/review-document-skill` | review-document skill + review report + workflow findings |

## 參考文件位置

| 文件 | 路徑 |
|------|------|
| 專利概念報告（含第一輪修訂）| `docs/patent/hardware_hot_cold_sensing_patent_report.md` |
| 主管回饋 + AI 討論 | `docs/patent/review.md` |
| 研究筆記 | `docs/patent/research-notes.md` |
| 主管專利參考 | `docs/patent/P51140026-...組評修訂版.md` |
| 風格分析 | `docs/patent/reference-style-analysis.md` |
| Review report | `feat/review-document-skill` branch: `docs/reviews/patent-report-review-2026-04-16.md` |
| Spec / Plan / Tasks | `.specify/specs/patent-revision-phase1/` |
