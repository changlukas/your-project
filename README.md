# AI Dev Workflow Template

Claude Code 的通用專案骨架，整合 [obra/superpowers](https://github.com/obra/superpowers)
（MIT）的 ephemeral subagent + skills 模型，同時保留文件專案專屬流程。

**核心心智模型：** Task 執行者是 ephemeral subagent，不是 persistent named role。
每個 task 一個 fresh subagent，context 不跨 task 累積。詳見 `docs/design/AGENT_MODEL.md`。

適用於：
- Code 專案（軟體、硬體、RTL）
- 文件專案（規格書、專利、技術報告、白皮書）

## 快速開始

```bash
gh repo create my-project --template <this-repo> --clone
cd my-project
bash bootstrap.sh          # 非互動式一鍵初始化
claude
> /setup                   # 或互動式引導設定
```

詳細說明見 [SETUP_GUIDE.md](SETUP_GUIDE.md)。

## 目錄結構與你要改什麼

這個 repo 的**根目錄**就是你的 project root。使用此 template 建立新 repo 後：

```
my-project/               ← 這一層就是「你要改名的地方」；名字由 gh repo create 決定
├── .claude/              ← 本 template 的機制，保留不動
├── .specify/             ← bootstrap.sh 建立的 spec/plan 目錄
├── CLAUDE.md             ← 你自己寫（或 /setup 產生）
├── README.md             ← 換成你專案的 README
├── SETUP_GUIDE.md        ← 可刪除（或改為你專案的 setup 說明）
└── <你的 code>           ← 直接放在根目錄（例如 src/、tests/）
```

**重點：** 你的 code 和 `.claude/` 必須**同層**。Claude Code 從 cwd 往上找 `.claude/`
才能載入 skills/agents/hooks，不要把 code 放到 `.claude/` 裡面或更深的子目錄。

> 本 template 在 local 開發時的資料夾叫 `your-project/`，就是為了提醒你：
> **這一層就是給你改成自己 project name 的位置**。透過 `gh repo create` 建立新 repo
> 時會自動用你指定的 repo 名稱，不需要手動 rename。

## 內建的工作流入口

### 首次設定
- `/setup` — 互動式首次專案設定 wizard（自家）

### Code 專案（Superpowers flow）
- `/brainstorming` — Spec 階段對話，HARD-GATE design approval
- `/writing-plans` — 將 spec 轉為 implementation plan
- `/executing-plans` — 單一 session 執行 plan
- 執行階段實際由 `subagent-driven-development` skill 驅動，逐 task dispatch fresh subagent

### 文件專案（自家 flow）
- `/write-document` — 4-phase persistent writer flow（Spec → Structure → Chapter Tasks → Drafting Cycle → Final Review）

### Bug 修復
- `/bugfix` — 4-phase bug fix flow（Report → Analyze → Fix → Verify），Phase 3 使用 Superpowers subagent-driven pattern

### Session 接棒 / 跨 session 交接
- `/brief` — 寫 session-brief.md 並 commit（session 結束前 checkpoint）
- `/start` — 讀前一 session 的 brief + git status，摘要進度
- `/reflect` — 掃對話中的修正與 approval，提議 skill 更新（continuous learning）

## 內建 Skills 清單

### 自家 skills（4 個）
| Skill | 用途 |
|---|---|
| `setup` | 首次專案互動式設定 wizard |
| `bugfix` | Bug 修復 4-phase 流程 |
| `write-document` | 文件專案 4-phase 流程 |
| `karpathy-guidelines` | Karpathy LLM coding 行為準則。Vendored 自 [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)（MIT） |

### Session handover skills（3 個，vendored from [t0ddharris/claude-code-skills](https://github.com/t0ddharris/claude-code-skills)，MIT）
| Skill | 用途 |
|---|---|
| `brief` | 寫 `/brief/session-brief.md` 並 commit + push 到 git |
| `start` | 讀 `/brief/session-brief.md` + git 狀態，回報上次進度 |
| `reflect` | 掃當前對話中的修正與 pattern，提議 skill 更新 |

### Superpowers vendored skills（14 個）
| Skill | 用途 |
|---|---|
| `brainstorming` | Spec 階段對話，HARD-GATE |
| `writing-plans` | Implementation plan 撰寫 |
| `executing-plans` | 單一 session 執行 plan |
| `subagent-driven-development` | Fresh subagent per task + two-stage review |
| `test-driven-development` | TDD Iron Law |
| `systematic-debugging` | Root-cause 導向的 debug 流程 |
| `requesting-code-review` | 請求 review 的結構 |
| `receiving-code-review` | 收到 review 的處理流程 |
| `verification-before-completion` | Task 完成前 self-check gate |
| `dispatching-parallel-agents` | Wave 平行 dispatch |
| `using-git-worktrees` | Worktree 隔離慣例 |
| `finishing-a-development-branch` | Branch 收尾與 PR 開立 |
| `using-superpowers` | Superpowers meta 入口 |
| `writing-skills` | Meta-skill：用 TDD 方式撰寫新 skill |

授權與修改細節見 [.claude/ATTRIBUTION.md](.claude/ATTRIBUTION.md)。

## 預設 Agents（4 個）

| Agent | 類型 | 職責 | 出處 |
|---|---|---|---|
| `task-executor` | Ephemeral（worktree） | Code task 執行者，每次 fresh dispatch，遵守 TDD Iron Law + karpathy-guidelines | 自家 |
| `code-reviewer` | Ephemeral（每次新 dispatch） | Two-stage review：spec alignment → code quality | Vendored 自 Superpowers |
| `writer` | Persistent | 文件專案撰寫（跨章節保有語氣/術語記憶） | 自家 |
| `verifier` | Persistent | 文件專案事實查核、交叉比對 | 自家 |

### 為什麼 Code 用 ephemeral 而文件用 persistent？

- Code task 之間獨立：fresh subagent 避免 context 污染、scope 自然 enforce
- 文件章節需要跨章術語一致與敘事脈絡：persistent writer 累積的共識有價值

詳細論證見 `docs/design/AGENT_MODEL.md`。

## Git 流程

```
main（受保護，由 PreToolUse hook + permissions.deny 雙重阻擋直接編輯/推送）
└── feat/{name}（Spec/Plan/Tasks phase 在此 commit）
    ├── feat/{name}/T001（Phase 4 worktree 隔離，fresh task-executor）
    ├── feat/{name}/T002
    └── ...
```

## 硬性約束（由 hooks + permissions 強制）

### 由 settings.json hooks 確定性執行
- ❌ `main` / `master` 直接編輯 → `branch-enforce.sh` 擋住
- ❌ 非 `feat/*` `chore/*` `docs/*` `bugfix/*` branch 編輯 → `branch-enforce.sh` 擋住
- ❌ Worktree 命名違反 `feat/*/T00X` `feat/bugfix-*/fix` `feat/bugfix-*/T00X` → `worktree-enforce.sh` 擋住
- ❌ `git push --force` / `push to main/master` / `rebase main/master` / `reset --hard origin*` / `clean -fdx` → `permissions.deny` 擋住
- ❌ `rm -rf *` → `permissions.deny` 擋住
- ✅ User prompt → `skill-router.sh` 自動匹配 keyword 注入 skill 路由提示
- ✅ Subagent 生命週期記錄到 `.claude/logs/agent-activity.jsonl`
- ✅ Subagent 完成桌面通知
- ✅ Pre-commit hook（若啟用 `pre-commit` framework）強制 conventional commit 格式 + gitleaks secret 掃描

### Opt-in scope enforcement
- 設定後 → `scope-enforce.sh` 擋掉編輯 scope 外檔案
- 啟用：`bash .claude/scripts/scope set src/auth/`
- 解除：`bash .claude/scripts/scope clear`
- 預設關閉，需要使用者明確 opt-in

## Optional Enhancements

以下第三方 plugin 非必須，但可進一步補強 enforcement：

- **[nizos/tdd-guard](https://github.com/nizos/tdd-guard)** (MIT) — TDD Iron Law plugin，阻擋沒有 failing test 就寫 production code，支援多種 test runner
  ```
  /plugin install tdd-guard
  ```

- **[backnotprop/plannotator](https://github.com/backnotprop/plannotator)** (MIT/Apache-2.0) — Plan review 視覺化 UI，在 ExitPlanMode 時打開 browser 標註 plan
  ```
  /plugin marketplace add backnotprop/plannotator
  /plugin install plannotator
  ```

- **pre-commit framework** — `bootstrap.sh` 會嘗試自動安裝；若失敗請手動：
  ```
  pipx install pre-commit
  pre-commit install
  ```
