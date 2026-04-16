今天的報告，主管給我的回饋是非常模糊，而且目前就已經在系統層級在管理這件事了，而且我的實施例也非常不清楚

4月13日

分析了三項主管回饋並規劃改進策略。
分析了三項主管回饋並規劃改進策略。
這三個回饋其實指向同一個根本問題：你沒有讓主管明確感受到「軟體做不到、硬體才能做到」的那條線在哪裡。

逐點分析：

「非常模糊」
你的投影片從頭到尾在講的是「感知單元觀察流量、合成分數、產生 hint」，但主管聽完不知道：

這個分數具體長什麼樣？數字？幾個 bit？
跨越閾值後到底發生什麼事？hint 長什麼樣？
從觀察到產生 hint 要多久？微秒？奈秒？
區域狀態表有多大？能追蹤幾個 region？
你一直在講「概念」而不是「機制」。對主管來說，概念層級的東西聽起來就像「我想做一個硬體來管記憶體冷熱」——這當然模糊。

改法：下一版報告需要一頁「具體運作範例」，用實際數字走一遍：

例：Region A 的 score 變化

cycle 0:     score = 0
cycle 100:   被存取 5 次 → score = 5
cycle 1000:  右移衰減 → score = 2
cycle 1100:  又被存取 8 次 → score = 10
cycle 1200:  score = 10 > promote 閾值(8) → 產生 hint
             → IRQ 通知 CPU
             → CPU 讀 CSR：「Region A, promote」
             → CPU 啟動 DMA：DDR → HBM
             → 搬遷完成，清除 migration pending flag
主管看完這個就知道「原來是這樣運作的」。

「系統層級已經在管了」
主管說的沒錯。OS 的 AutoNUMA、CUDA Unified Memory、numactl 確實在管這件事。你的報告沒有回答清楚的是：既然軟體已經在管了，為什麼還需要硬體？

你需要一頁直接正面對決這個問題：

軟體管的問題：

1. 速度：OS 掃描週期 ~60 秒，AI workload 的存取 pattern
        可能在毫秒內就變了。等 OS 發現時早就來不及。

2. 精度：AutoNUMA 只知道「有/沒有被存取」（二元），
        不知道「多常被存取」（連續分數）。
        無法區分「偶爾存取一次」和「密集存取中」。

3. 預測：軟體完全沒有預測能力。
        每次都是「存取 miss → 才搬遷 → 等待」。
        不會學習「A 變熱之後 B 通常跟著變熱」。

4. 視野：OS 的 page table 掃描是 per-CPU 的。
        不知道其他 CPU 或加速器也在存取同一塊資料。

硬體解決的是：
  把 60 秒的反應時間壓到硬體速度（cycle 級）
  把二元判斷升級為連續分數 + 三策略整合
  加入序列規律學習的預測能力
  在互連匯聚點觀察，天然全域可見
「實施例不清楚」
LLM+LoRA 和 MoE 的問題是：主管不確定這些場景真的需要你的硬體。

主管可能在想：

LLM+LoRA：「軟體直接把推理和訓練的記憶體切開不就好了？為什麼要硬體自動管？」
MoE：「軟體 prefetch 不就行了？Pre-gated MoE 不是已經在做了？」
你的實施例缺少一個關鍵環節：「軟體嘗試過了，但做不好，數據在這裡」。

每個實施例需要這個結構：

1. 場景：（什麼 workload）
2. 軟體怎麼做：（現有的做法，具體方案名稱）
3. 軟體做不好的數據：（引用論文的具體數字）
4. 本案怎麼做：（硬體的具體機制）
5. 為什麼硬體做得到軟體做不到：（速度/精度/預測的差異）
例如 MoE：

場景：MoE 推理，256 experts，HBM 只能放 64 個

軟體怎麼做：LRU cache + on-demand loading
           （Expert 不在 HBM → fault → 搬遷 → 等待）

軟體做不好的數據：
  Expert 搬遷佔推理延遲 85-95%（HOBBIT, 2024）
  軟體 prefetch（Pre-gated MoE）需額外訓練模組，
  且在 fine-grained expert 架構上效果下降（MoBiLE, 2025）

本案怎麼做：
  行為學習表觀察「E1 冷轉熱後 E3 通常跟著冷轉熱」
  重複出現 → 確認規律
  下次 E1 冷轉熱 → 自動對 E3 加分 → promote hint
  → DMA 在背景搬遷 E3 → Gating 選到 E3 時已在 HBM

為什麼軟體做不到：
  Gating network 只看當前 token，沒有跨 token 記憶
  軟體 prefetch 需要 per-model 訓練，換模型就要重練
  硬體行為學習表自動學習，不需要訓練，適用任何 MoE 模型
下一步建議
你需要重做報告，但不是全部重做。核心問題是缺少一頁直接回答「為什麼軟體不夠」。建議加或改這三頁：

新增一頁：「為什麼軟體層級管理不足」— 速度/精度/預測/視野四個維度的對比表，附具體數字
新增一頁：「具體運作範例」— 用實際數字走一遍 score → 閾值 → hint → 搬遷 的完整流程
改寫實施例：每個實施例補「軟體怎麼做 → 做不好的數據 → 本案怎麼做 → 為什麼硬體做得到」
要我幫你做哪一頁？

實施例的部分沒有明確的表達出實際的場景，例如我的專利到底怎麼管理冷熱的搬遷

4月13日

構思具體步驟展示專利冷熱數據遷移機制。
構思具體步驟展示專利冷熱數據遷移機制。
你的投影片目前停在「感知單元產生 hint，CPU 執行搬遷」這個層級，主管聽完不知道中間到底發生了什麼。你需要一頁用具體數字把整個流程跑一遍。

用 MoE 實施例，因為它最能展示預測策略的價值：

前提：256 experts，HBM 只能放 64 個
     promote 閾值 = 8，demote 閾值 = 3
     每 1000 cycles 右移衰減一次（score 減半）
     行為學習表 confidence 閾值 = 3（出現 3 次確認規律）

═══════════════════════════════════════════════════════
第 1-3 輪推理（學習階段）
═══════════════════════════════════════════════════════

  每輪推理中，Gating 都選中 Expert 1 → 接著選中 Expert 3

  感知單元觀察到的冷轉熱事件序列：
  第 1 輪：Expert 1 冷轉熱 → Expert 3 冷轉熱
          行為學習表記錄 1→3，confidence = 1
  第 2 輪：又觀察到 1→3，confidence = 2
  第 3 輪：又觀察到 1→3，confidence = 3 ≥ 閾值
          → 規律確認 ✓

  這三輪中 Expert 3 都是被動搬遷（等 fault 才搬），有等待

═══════════════════════════════════════════════════════
第 4 輪推理（預測生效）
═══════════════════════════════════════════════════════

  cycle 0     Expert 1 不在 HBM，score = 0
              Gating 選中 Expert 1
              → fault → DMA 搬遷 Expert 1 到 HBM
              （這次的 cold miss 無可避免）

  cycle 200   Expert 1 搬遷完成，開始被存取
              score: 0 → 3 → 6 → 9
                                  ↑
                              score 9 > promote 閾值 8
                              → 冷轉熱事件觸發

  cycle 200   冷熱判定單元同時做兩件事：
              ┌─────────────────────────────────┐
              │ 1. 產生 Expert 1 的 promote hint │
              │    （但 Expert 1 已經在 HBM 了） │
              │                                 │
              │ 2. 將冷轉熱事件分發給預測性策略    │
              │    → 查行為學習表                │
              │    → 命中：1→3，confidence = 3   │
              │    → 對 Expert 3 加分            │
              │    → Expert 3 score 跨越閾值     │
              │    → 產生 Expert 3 的 promote hint│
              └─────────────────────────────────┘

  cycle 201   CPU 收到中斷，讀 CSR：
              「Expert 3，建議 promote」
              CPU 判斷 Expert 3 目前在 DDR
              → 啟動 DMA：DDR → HBM
              → 設定 migration pending flag

  cycle 201   同時，運算單元正在用 Expert 1 計算
  ~500        （DMA 在背景搬 Expert 3，不影響運算）

  cycle 500   DMA 完成，Expert 3 已在 HBM
              CPU 清除 migration pending flag

  cycle 600   Gating 選中 Expert 3
              → Expert 3 已在 HBM ★
              → 直接開始計算，零等待

═══════════════════════════════════════════════════════
同時間，不再被使用的 Expert 的 score 變化
═══════════════════════════════════════════════════════

  Expert 42（很久沒被選中）：
  cycle 0:     score = 7（之前累積的）
  cycle 1000:  右移衰減 → score = 3
                                   ↑
                               score 3 ≤ demote 閾值 3
                               → 觸發 demote hint

  CPU 收到：「Expert 42，建議 demote」
  → DMA：HBM → DDR
  → HBM 空間騰出給其他 expert
這個流程走完，主管就能看到五件事：

score 怎麼算：存取就加分，週期性減半
閾值怎麼觸發：score 超過 8 就 promote，低於 3 就 demote
預測怎麼運作：觀察 3 次 1→3 確認規律，第 4 次自動預測
搬遷怎麼發生：hint → IRQ → CPU 讀 CSR → DMA 背景搬遷
冷資料怎麼清除：右移衰減讓不用的 expert 自動歸零 → demote
建議你做成一頁投影片，用時間軸 + 數字呈現，不要用文字段落。

我的問題應該是我一直卡在我要怎麼知道遠端記憶體若有即將變熱的資料，那我要怎麼知道？因為這個實際的例子比較能反應我們前面一直在說的hbm容量不夠，需要preload的感覺

4月13日

解析感測單元如何透過預測策略預先偵測遠端記憶體熱資料。
解析感測單元如何透過預測策略預先偵測遠端記憶體熱資料。
你問到了整個專利最核心的機制。讓我把它拆解清楚：

先釐清一件事：感知單元不知道資料在哪一層記憶體
感知單元知道的：
  這個位址的 region 被存取了幾次、score 多少

感知單元不知道的：
  這個 region 的資料現在放在 HBM 還是 DDR

知道資料在哪的是軟體（CPU/FW），不是感知單元。
所以你的問題應該拆成兩個：

問題 1：已經開始被存取的遠端資料，怎麼知道它變熱了？
這個靠時間策略，而且是被動的：

Expert 128 在 DDR 中，目前 score = 0

Gating 選中 Expert 128
  → 運算單元發出 read request
  → request 經過互連
  → 感知單元窺探到這個位址 → score +1
  → 更多 request → score 持續上升
  → score 超過 promote 閾值 → 產生 hint

CPU 收到 hint：「Region X（Expert 128 的位址）建議 promote」
CPU 查自己的 page table：「Region X 目前在 DDR」
  → 啟動 DMA：DDR → HBM

但問題是：這時候運算單元已經在等了。
第一次一定是 cold miss，避不掉。
這和 CHMU / NeoMem 沒有本質差別——都是先存取、才偵測、再搬遷。

問題 2：還沒被存取的遠端資料，怎麼提前知道它即將變熱？
這才是你專利真正的價值，靠的是預測策略：

前提：行為學習表已確認規律「Expert 1 → Expert 3」

Expert 1 開始被存取（Gating 選中它）
  → 感知單元看到 Expert 1 的位址被大量存取
  → Expert 1 score 上升 → 跨越 promote 閾值
  → 冷轉熱事件觸發

  此時預測策略啟動：
  ┌────────────────────────────────────────────┐
  │ 查行為學習表：Expert 1 → Expert 3（已確認）  │
  │                                            │
  │ Expert 3 目前 score = 0                     │
  │ 沒有任何人在存取它                           │
  │ 但預測策略直接對它加分                       │
  │ → score 從 0 被推到超過 promote 閾值         │
  │ → 產生 Expert 3 的 promote hint             │
  └────────────────────────────────────────────┘

CPU 收到 hint：「Region Y（Expert 3 的位址）建議 promote」
CPU 查 page table：「Region Y 目前在 DDR」
  → 啟動 DMA：DDR → HBM（背景搬遷）

此時運算單元還在算 Expert 1，不需要 Expert 3
等 Gating 選到 Expert 3 時 → 已經在 HBM 了 → 零等待
關鍵：感知單元從來沒有看到 Expert 3 被存取。 它是根據 Expert 1 的冷轉熱事件，查表後「無中生有」地對 Expert 3 加分。這就是預測的本質——不是觀察到了才反應，而是根據歷史規律提前行動。

用一張圖總結
                    感知單元看得到              感知單元看不到
                    （互連上有 request）        （還沒有 request）
                         │                         │
                         ▼                         ▼
  時間策略 ──► 「Expert 1 正在被存取，       無法處理
               score 上升，判定為熱」

  預測策略 ──► Expert 1 冷轉熱觸發 ──────► 「Expert 3 雖然沒人
               查行為學習表                  在存取，但根據歷史
                                            規律，它即將被用到，
                                            對它加分 → 產生 hint
                                            → 提前搬進 HBM」

  這就是你的專利和所有 prior art 的根本差異：
  CHMU / NeoMem / AutoNUMA 都只能處理左邊那欄
  你的方案能處理右邊那欄
投影片建議
你需要一頁專門講這個，標題就叫：

「如何預知遠端資料即將變熱？」

內容只需要三個階段：

1. 學習：觀察冷轉熱事件的先後順序
        「Expert 1 變熱後 Expert 3 通常跟著變熱」
        重複 3 次 → 確認規律

2. 預測：Expert 1 再次冷轉熱時
        查表命中 → 對 Expert 3 加分
        Expert 3 此時沒有被任何人存取

3. 搬遷：Expert 3 score 跨越閾值
        → hint 通知 CPU
        → DMA 背景搬遷 DDR → HBM
        → Gating 選到 Expert 3 時已在 HBM
這一頁回答了主管最核心的疑問：「你的硬體怎麼知道還沒被用到的資料即將變熱？」答案是：它不知道，但它從歷史中學到了規律，並據此提前行動。

還是說不要用MoE,用weight, kv cache 之類的

4月13日

權衡了MoE與替代方案，認定MoE最適合但需簡化呈現。
權衡了MoE與替代方案，認定MoE最適合但需簡化呈現。
MoE 是最好的例子，不要換。原因：

LLM layer weights 的問題：
  Layer 0 → 1 → 2 → ... → 79
  這是靜態序列，compile time 就知道
  軟體用 scheduler 就能排好（FlexGen 已證明）
  → 主管會問：為什麼需要硬體預測一個已知的順序？

KV cache 的問題：
  每個 token 生成時 KV cache 往後長一格
  pattern 是線性增長，完全可預測
  → 主管會問：這不就是一直 append 嗎？需要預測什麼？

MoE 為什麼對：
  每個 token 進來，Gating 選哪個 expert 是動態決定的
  軟體事先不知道下一個 token 會用哪個 expert
  但歷史上有統計規律（某些 expert 常被一起用）
  → 這才是「軟體不知道，但硬體能從歷史中學到」的場景
你的問題不是例子選錯，而是MoE 的背景解釋佔了太多篇幅，主管還沒聽到你的方案就已經迷路了。

建議改法：不要花時間解釋 MoE 架構，直接用主管能秒懂的比喻框定問題：

場景：
  加速器上有 256 個運算模組，但 HBM 只放得下 64 個的資料。
  每次運算只用其中 2 個，用完換下一組。
  哪 2 個會被用到是動態決定的，事先無法預知。

問題：
  選中的模組資料不在 HBM → 等搬遷（佔推理延遲 85-95%）
  軟體沒有跨次運算的記憶，每次都是被動等待。

本案：
  感知單元觀察歷史：「模組 A 被用之後，模組 B 通常跟著被用」
  重複出現 3 次 → 確認規律
  下次模組 A 被用 → 自動提前搬遷模組 B 到 HBM
  → 模組 B 被選中時已在 HBM，零等待
先讓主管懂「256 選 2、放不下、要等搬遷」這個問題，再告訴他「硬體能學會誰跟誰常一起出現」。最後才說「這就是 MoE 推理的場景」。先講問題和解法，最後才貼標籤。

那how to work呢

4月13日

构思了感知单元数据迁移的具体演示方案。
构思了感知单元数据迁移的具体演示方案。
緊接著上一頁的「場景/問題/本案」，下一頁直接用數字走一遍：

How it works — 以模組 A、B 為例

前提：promote 閾值 = 8，demote 閾值 = 3
     每 1000 cycles 右移衰減（score 減半）
     行為學習表 confirmation 閾值 = 3

────────────────────────────────────────
Phase 1：學習（前 3 輪運算）
────────────────────────────────────────

  第 1 輪：模組 A 被選中 → score 上升 → 冷轉熱
          接著模組 B 被選中 → score 上升 → 冷轉熱
          行為學習表記錄 A→B，confidence = 1

  第 2 輪：又觀察到 A→B，confidence = 2

  第 3 輪：又觀察到 A→B，confidence = 3 ≥ 閾值
          規律確認 ✓

  這三輪中模組 B 都是「被選中 → 不在 HBM → 等搬遷」

────────────────────────────────────────
Phase 2：預測生效（第 4 輪）
────────────────────────────────────────

  模組 A 被選中，開始被存取
  感知單元：A 的 score 上升 → 跨越 promote 閾值 → 冷轉熱事件

  冷熱判定單元做兩件事：

  ① 對 A 產生 promote hint
     （A 已在 HBM，hint 被忽略）

  ② 將冷轉熱事件分發給預測性策略
     查行為學習表 → 命中 A→B（已確認）
     對 B 加分 → B 的 score 跨越 promote 閾值
     對 B 產生 promote hint
     → 此時 B 沒有被任何人存取

  CPU 收到中斷，讀 CSR：「模組 B，建議 promote」
  CPU 查 page table：B 目前在 DDR
  → 啟動 DMA：DDR → HBM（背景搬遷）
  → 設定 migration pending flag

  同時間，運算單元正在用模組 A 計算
  DMA 在背景搬 B，不影響運算

  DMA 完成 → B 已在 HBM → 清除 flag

  模組 B 被選中 → 已在 HBM → 直接計算，零等待 ★

────────────────────────────────────────
Phase 3：自動清理（持續進行）
────────────────────────────────────────

  模組 C（很久沒被選中）：
  score = 7
  → 1000 cycles 後右移 → score = 3
  → score ≤ demote 閾值
  → 產生 demote hint
  → CPU 搬遷 C：HBM → DDR
  → 騰出 HBM 空間給下一個被預測的模組
投影片呈現方式建議用時間軸圖而非文字：

  時間軸 ──────────────────────────────────────────►

  運算：   [模組 A 計算中]         [模組 B 計算中]
                │                      │
  感知：   A score ↑                   │
           A 冷轉熱 ─┐                │
                     │                │
  預測：        查表 A→B              │
               對 B 加分              │
               B hint ─┐             │
                       │             │
  搬遷：          DMA: B DDR→HBM     │
                  (背景，不影響 A)     │
                       │             │
                  B 已在 HBM ────────★ 零等待

  同時：   C score 持續衰減 → demote → 騰出空間
這樣一頁投影片回答了主管所有的疑問：score 怎麼變、閾值怎麼觸發、預測怎麼運作、搬遷怎麼發生、舊資料怎麼清除。全部用具體數字和時間軸呈現，不再是概念描述。

我的主管還問了一個問題就是我的命名，我到底是在感知還是管理

4月13日

評估專利功能介於感知與管理之間的定位。
評估專利功能介於感知與管理之間的定位。
你主管問得好。看你的專利實際做的事：

感知單元做的事：
  ✓ 窺探存取流量          ← 這是感知
  ✓ 計算冷熱分數          ← 這是評估
  ✓ 學習序列規律          ← 這是預測
  ✓ 產生 placement hint   ← 這是建議

感知單元不做的事：
  ✗ 決定搬去哪           ← 軟體決定
  ✗ 執行搬遷             ← DMA 執行
所以叫「感知」太窄，叫「管理」太寬：

感知（sensing）：只觀察，不輸出判斷  ← 你做的比這多
管理（management）：從判斷到執行全包  ← 你沒做到這步
你的專利卡在中間——觀察 + 評估 + 預測 + 建議，但不執行。比較精確的定位是：

感知 + 評估 + 建議 = Advisory

你的專利是一個 advisory engine，不是 sensor 也不是 manager
命名建議：

現在：
  硬體資料溫度「感知」

可考慮改成：
  硬體資料溫度感知與放置建議
  Hardware Data Temperature Sensing and Placement Advisory

或更簡潔：
  記憶體層級放置建議引擎
  Memory Tier Placement Advisory Engine
但如果你不想改專利名稱（已經送出或已經對齊），投影片上可以用一頁說清楚邊界：

本案的角色定位

  感知：旁路窺探存取流量
  評估：三策略合成冷熱分數
  預測：行為學習表學習序列規律
  建議：產生 placement hint 通知 CPU
  ──────────────────────────────
  決策：軟體判斷是否採納 hint
  執行：軟體透過 DMA 搬遷

  本案負責「感知到建議」，軟體負責「決策到執行」
這樣主管就知道你的命名裡的「感知」其實是簡稱，實際範圍是「感知 + 評估 + 預測 + 建議」，但刻意不管「決策 + 執行」——這是設計選擇，不是功能不足。

所以按照你的意思其實我的專利只適合你應用在MoE推理架構上嗎？這個問題很重要，你需要仔細思考，到底其他架構下是不是系統層就已經解決了這個問題

4月13日

審視專利核心適用範圍與系統層解決方案。
審視專利核心適用範圍與系統層解決方案。
Claude's response was interrupted
所以按照你的意思其實我的專利只適合你應用在MoE推理架構上嗎？這個問題很重要，你需要仔細思考並且查證，到底其他架構下是不是系統層就已經解決了這個問題

4月13日

審視專利適用範圍，逐一檢驗軟體層是否已解決問題。
審視專利適用範圍，逐一檢驗軟體層是否已解決問題。
這個問題非常關鍵，我不能只憑概念回答。讓我查證每個場景下軟體到底做到什麼程度。


評估專利適用場景，確認非僅限MoE推理架構。
評估專利適用場景，確認非僅限MoE推理架構。
不只適用 MoE，但你的專利價值確實不是均勻分佈在所有場景。讓我誠實地逐個分析：

軟體已經解決（或接近解決）的場景
LLM 逐層推理（layer-by-layer weight swap）
  軟體做法：FlexGen LP scheduler，compile time 排好
  結論：靜態序列，不需要硬體預測 → 你的專利沒有額外價值

KV Cache 管理
  軟體做法：PagedAttention / vLLM，線性增長完全可預測
  結論：pattern 太簡單，軟體足夠 → 你的專利沒有額外價值

一般伺服器 CXL memory tiering
  軟體做法：TPP / MEMTIS / Colloid（ASPLOS '24）+ CHMU
  結論：存取 pattern 變化速度慢（秒級），
       軟體毫秒級反應足夠 → 你的專利價值有限
軟體有方案但效果有限的場景
推理 + 訓練共用加速器（你的實施例 1）
  軟體做法：Sirius（ATC '25）軟體層動態記憶體交接
  軟體的限制：需要軟體持續介入調整邊界，
            epoch 切換的反應依賴 OS 排程延遲
  你的專利價值：時間策略 + 區間化配置可以減少軟體介入頻率
  但問題是：Sirius 已經做得不錯了（SLO 合規率提升 57-97%），
          你需要論證硬體能做得更好的具體數據
  結論：有價值但不是殺手級場景
軟體真正做不好的場景
這類場景的共同特徵：存取 pattern 是動態的、資料依賴的、在 runtime 才決定的，而且變化速度是微秒級。

場景 1：MoE expert routing（你的實施例 2）
  為什麼軟體不夠：
  - Gating 每個 token 動態決定用哪個 expert
  - 軟體事先不知道下一個 token 會選誰
  - 軟體 prefetch（Pre-gated MoE）需要 per-model 訓練，
    換模型就失效，且在 fine-grained expert 架構上效果下降
  - 搬遷延遲佔推理時間 85-95%（HOBBIT, 2024）
  你的專利價值：行為學習表自動學習跨 token 的 expert 序列規律，
              不需要 per-model 訓練，適用任何 MoE 模型
  結論：★ 最強場景
場景 2：推薦系統的 embedding table lookup
  規模：Meta 的 DLRM embedding table 達 TB 級，
       遠超單 GPU HBM 容量
  為什麼軟體不夠：
  - 哪些 embedding 被查詢取決於用戶輸入，runtime 才知道
  - 存取有 skewness（熱門商品的 embedding 被頻繁存取）
  - 熱門集會隨時間漂移（trending topics 變化）
  - 某些 embedding 有共現規律（買了 A 的人常看 B）
  你的專利價值：
  - 時間策略：追蹤 embedding region 的存取頻率，自動識別熱門
  - 預測策略：學習「embedding A 變熱後 embedding B 跟著變熱」
  - 空間策略：相關商品的 embedding 通常在位址空間中相鄰
  結論：★ 強場景，而且產業規模巨大
場景 3：Multi-model serving（多模型動態載入）
  場景：同一張加速器服務多個不同模型，
       根據 request 類型動態載入對應模型
  為什麼軟體不夠：
  - 哪個模型被請求取決於用戶流量，runtime 才知道
  - 但流量有統計規律（工作時間多 code 模型，晚上多 chat 模型）
  - 軟體排程只能基於歷史統計做靜態預分配
  你的專利價值：
  - 行為學習表觀察「模型 A 變熱後模型 B 常跟著變熱」
  - 自動學習流量的時段規律，不需要人工配置
  結論：中等場景，但說服力不如 MoE
總結
你的專利適用條件：
  ✓ 存取 pattern 是動態的、runtime 決定的
  ✓ 軟體事先無法預知下一個會用到什麼資料
  ✓ 但歷史上有統計規律可以學習
  ✓ 資料量超過近端記憶體容量
  ✓ 反應速度需求是微秒級，軟體的毫秒級不夠快

你的專利不適用的條件：
  ✗ 存取 pattern 是靜態的、compile time 已知
  ✗ 軟體 scheduler 可以 optimal 排程
  ✗ pattern 變化速度慢，毫秒級反應足夠
所以答案是：不只 MoE，但確實只適用於「動態、runtime 決定、有統計規律可學習」的場景。 MoE 是最佳實施例，推薦系統 embedding table 是第二個強場景。LLM 逐層推理和 KV Cache 不適用。

如果主管再問「這是不是太窄了」，你的回答是：MoE 已經是當前最主流的大模型架構（GPT-4、DeepSeek-R1、Llama 4 都是 MoE），而推薦系統是全球流量最大的 AI 應用（Meta、Google、TikTok）。這兩個場景覆蓋了 AI 產業最大的兩個市場。

把你找到的關於場景1，2，3的文獻找給我

4月13日

蒐集文獻資料並探索多模型服務相關研究。
蒐集文獻資料並探索多模型服務相關研究。
整理三個場景的文獻如下：

場景 1：MoE Expert Routing
論文	來源	關鍵數據
HOBBIT	arXiv 2411.01433, 2024	Expert loading 佔推理時間 85.5%（RTX 4090）和 94.5%（Jetson Orin） 
arXiv
MoBiLE	arXiv 2510.12357, 2025	現有 prefetch 方法往往有顯著的訓練開銷，且在近期採用細粒度 expert 分割的 MoE 模型上效果下降 
arXiv
DynaExq	arXiv 2511.15015, 2026	同一模型同一層，在 text、math、code 三種 workload 下，最常被啟用的前 10 個 expert 可以完全不同 
arXiv
SpecMoEOff	arXiv 2508.21706, 2025	DeepSeek-R1 即使 8-bit 量化仍需 671 GB，MoE 模型對消費級 GPU 構成重大部署挑戰 
arXiv
FineMoE	arXiv 2502.05370, 2025	FineMoE 記錄 expert maps 追蹤細粒度的 expert 啟用 pattern，用歷史 request 的 semantic 和 trajectory 相似度引導 prefetch 
arXiv
場景 2：推薦系統 Embedding Table
論文	來源	關鍵數據
RecMG	HPCA 2025	DLRM 記憶體容量需求達 TB 級。20% 的 embedding vector 存取的 reuse distance 超過 2^20，超出大多數 GPU buffer 大小，降低傳統 LRU caching 的效果 
Pasalabs
FAE (Hot-Embeddings)	ResearchGate, 2021	Criteo Kaggle 資料集上，前 6.8% 的 embedding table entry 佔了至少 76% 的總存取量。某些 entry 的存取次數差距高達 10000 倍 
ResearchGate
Hotline	arXiv 2204.05436, 2024	Hotline 利用推薦系統存取高度偏斜的特性，將頻繁存取的 embedding entry 放在 GPU HBM。Embedding 操作佔訓練時間高達 75%（Criteo Terabyte） 
arXiv
Fleche	ACM EuroSys 2022	DLRM 的 embedding 層佔預測延遲超過 60%。隨機 lookup 導致大量 CPU cache miss，多表同時存取耗盡 DRAM 頻寬 
ACM Digital Library
EMBark	RecSys 2024, NVIDIA	訓練資料集呈現 power-law skew（α = 1.2）。EMBark 在 DGX H100 上達到平均 1.5 倍、最高 1.77 倍的端到端訓練加速 
NVIDIA Developer
IISWC Tutorial	IISWC 2024	DLRM 是最大的 DNN workload 之一，參數量達數兆、大小達 TB 級。GPU HBM 容量有限，embedding table 的存取 pattern 有 skewness 可以被利用 
IISWC 2024 Tutorial
場景 3：Multi-Model Serving
這個場景的獨立文獻較少，但以下論文間接覆蓋：

論文	來源	相關內容
Sirius	USENIX ATC '25	GPU 推理利用率低於 15%。為滿足 SLO 即使在 burst 時，MLaaS 平台通常過量分配 GPU 資源 
Sjtu
LithOS	SOSP '25	在推理堆疊場景中，LithOS 比 MPS 降低尾延遲 13 倍，比最佳現有方案降低 4 倍，同時提升整體 goodput 1.3 倍 
ACM Digital Library
三個場景的適用性比較
              存取 pattern    軟體能預測嗎    你的專利價值
              ───────────    ──────────     ──────────

MoE           每 token 動態   ✗ Gating 只看    ★★★
              runtime 決定    當前 token       行為學習表自動學習
                                              跨 token 序列

Embedding     每 request 動態  △ 可做統計       ★★★
Table         用戶輸入決定     但 hot set 會    時間策略追蹤 skewness
                              隨時間漂移       預測策略學習共現規律

Multi-Model   每 request 動態  △ 可做流量預測   ★★
Serving       流量決定         但不精確         行為學習表學習
                                              時段規律
建議你的實施例選 MoE + Embedding Table。這兩個場景都有充分的頂級會議論文佐證「軟體做不好」，而且覆蓋了 AI 產業最大的兩個市場（LLM 推理 + 推薦系統）。

這兩個場景都有充分的頂級會議論文佐證「軟體做不好」，那目前有解法嗎

4月13日

盤點軟體解法侷限，確認硬體方案優勢。
盤點軟體解法侷限，確認硬體方案優勢。
有，但全部都是軟體層的解法，而且各自有明確的限制。這正是你專利的切入點。

MoE 現有解法及其限制
解法 1：LRU Cache（最基本）
  做法：GPU HBM 當作 expert cache，miss 就從 DDR 搬
  限制：完全被動，每次 miss 都要等
  文獻：MoE-Offloading（Eliseev, 2023）

解法 2：Pre-gated MoE
  做法：訓練額外的 gating 模組，提前一層預測下一層要用的 expert
  限制：需要 per-model 額外訓練，換模型就要重練
       對 fine-grained expert 架構效果下降
  文獻：Hwang et al., Pre-gated MoE, 2024

解法 3：Expert Activation Matrix（MoE-Infinity）
  做法：離線收集 workload 的 expert 啟用矩陣，推理時做 prefetch
  限制：需要離線 profiling，workload 改變就失效
       依賴 temporal locality 假設，不適用存取 pattern 快速變化的場景
  文獻：Xue et al., MoE-Infinity, 2024

解法 4：Expert Map（FineMoE）
  做法：記錄歷史 request 的 expert 啟用序列，
       用 semantic + trajectory 相似度搜尋匹配
  限制：需要維護 Expert Map Store，有儲存和搜尋開銷
       匹配依賴 request 層級的語意相似度，不是硬體層級
  文獻：FineMoE, arXiv 2502.05370, 2025

解法 5：Mixed Precision（HOBBIT / DynaExq）
  做法：cache miss 時用低精度版本替代，減少搬遷量
  限制：用精度換速度，有 accuracy trade-off
       沒有解決「預測」問題，只是讓 miss 的代價變小
  文獻：HOBBIT 2024, DynaExq 2026
共同限制：全部都是軟體層、需要 per-model 配置或離線 profiling、沒有一個是硬體透明的通用方案。

Embedding Table 現有解法及其限制
解法 1：Software Cache（Neo / HugeCTR）
  做法：GPU HBM 上建 32-way set-associative software cache
       用 LRU 或 LFU 做 replacement
  限制：LRU 對 long reuse distance 的 embedding 無效
       20% 的存取 reuse distance 超過 2^20
  文獻：Neo, ISCA 2022

解法 2：Hot Embedding Replication（FAE）
  做法：離線統計 hot embedding，複製到每個 GPU
  限制：hot set 是靜態的，離線統計完就不變
       如果 hot set 隨時間漂移（trending 變化），就失效
  文獻：FAE, VLDB 2022

解法 3：ML-Guided Prefetch（RecMG）
  做法：用 ML 模型預測哪些 embedding 即將被存取
  限制：需要訓練 ML 模型（labeling + search space）
       ML 模型本身消耗 GPU 運算資源
       換 workload 需要重新訓練
  文獻：RecMG, HPCA 2025

解法 4：Hardware Accelerator（Hotline）
  做法：硬體加速 pipeline，將 hot embedding 放 HBM、
       cold embedding 放 CPU DRAM，硬體做 gather
  限制：hot/cold 分類是離線靜態決定的
       不會隨 runtime 存取變化動態調整
       沒有預測共現規律的能力
  文獻：Hotline, arXiv 2204.05436, 2024
共同限制：hot set 要嘛是靜態離線決定的（FAE、Hotline），要嘛依賴額外的 ML 模型（RecMG）。沒有一個方案能在硬體層自動學習 runtime 的動態變化。

你的專利相對於這些解法的差異
                現有軟體解法              你的專利
               ─────────              ────────

配置需求        per-model 訓練           CSR 配置位址區間參數
               或離線 profiling          不需要知道 model 結構

hot set 更新   靜態（離線決定）           動態（右移衰減 +
               或需重新 profiling         持續觀察自動更新）

預測能力        無，或需額外 ML 模型       行為學習表自動學習
                                        序列規律，不需訓練

適用範圍        per-model                 通用，不綁定特定模型
               換模型需重新配置            或 workload

實作層級        軟體                      硬體
               受 OS 排程/中斷影響         cycle 級反應
所以你向主管報告時的論述是：

「這兩個場景都有大量學術論文在解決，但現有方案全部在軟體層。它們各自需要 per-model 訓練、離線 profiling、或額外的 ML 模型。本案提供的是硬體層級的通用方案——不需要知道 model 結構，不需要離線 profiling，CSR 配好位址區間參數後硬體自動運作。這不是取代軟體方案，而是在軟體之下提供一層硬體基礎設施，讓軟體可以更簡單。」