# USAGE — 完整使用手冊

這份文件是本 template 的**完整工作流參考**。每個 stage 都列出：
觸發條件 → 執行者 → 載入哪些 skill → 哪些 hook 被觸發 → 產出檔案路徑 →
commit 慣例 → APPROVE gates → 失敗 retry → 完成條件 → 範例對話 → gotchas。

> **心智模型**：本 template 採 ephemeral subagent + skills 模型。
> 完整論證見父層 `docs/design/AGENT_MODEL.md`（不隨 template 散播）。

> **重要**：本 template 是**兩層架構** —
> - **Vendored layer**: 14 個 Superpowers skills（obra/superpowers, MIT），用 `YYYY-MM-DD-` 前綴路徑、無強制 commit prefix、自帶 prompt-template subagents
> - **Custom layer**: 4 個自家 skills（setup/bugfix/write-document/karpathy-guidelines）、4 個 named agents、9 個 hooks、`.specify/{specs,bugs}/{name}/` 子目錄路徑、強制 commit prefix
>
> 兩層的 path/branch 慣例**不同**，使用者選不同入口流程會走不同分支。Section 2 / Section 8 詳細說明。

---

## Section 1: TL;DR — 三秒鐘決策樹

| 你想做什麼？ | 入口 | 流程強度 | 走哪一層？ |
|---|---|---|---|
| 新功能 (feature) | 直接描述需求 | **重**：Superpowers 5-step chain | Vendored |
| 修 bug | 直接描述 bug | **中**：4-phase flow | Custom |
| 寫文件 / 專利 / 報告 | 直接描述文件需求 | **中**：5-phase flow | Custom |
| 改 typo / comment / rename / 小修 | 直接告訴 AI 改什麼 | **無**：跳過所有流程 | 直接 main Claude |
| 問問題 / 看 code | 直接問 | **無**：純對話 | 直接 main Claude |
| 第一次設定 template | `bash bootstrap.sh` → `/setup` | 一次性 wizard | Custom |

### 入口指令速查

| 指令 | 用途 | 觸發方式 | 來源 |
|---|---|---|---|
| `bash bootstrap.sh` | 一次性環境初始化 | 第一次 clone 後手動 | Custom |
| `/setup` | 互動式設定 wizard | 第一次進 Claude Code | Custom skill |
| `/brainstorming` | Spec 階段對話（HARD-GATE） | 描述新功能後 AI 自動建議 | Vendored Superpowers |
| `/writing-plans` | spec → implementation plan | spec approved 後 | Vendored Superpowers |
| `/executing-plans` | 平行 session 執行 plan | plan 完成後 | Vendored Superpowers |
| `/subagent-driven-development` | 同 session dispatch 3 subagents per task | plan 完成後（推薦）| Vendored Superpowers |
| `/finishing-a-development-branch` | 收尾、merge、PR | 所有 task 完成後 | Vendored Superpowers |
| `/bugfix` | 4-phase bug 修復 | 描述 bug 後 AI 自動建議 | Custom skill |
| `/write-document` | 5-phase 文件流程 | 描述文件需求後 AI 自動建議 | Custom skill |
| `/systematic-debugging` | Root-cause 分析 4 phases | 任何 bug / 異常 | Vendored Superpowers |
| `/test-driven-development` | TDD Iron Law 規範 | 寫 code 前 | Vendored Superpowers |
| `/verification-before-completion` | self-check before claiming done | 宣稱完成前 | Vendored Superpowers |
| `bash .claude/scripts/scope set <path>...` | **opt-in** 啟用 scope enforcement | 想限制 task 範圍時 | Custom |
| `bash .claude/scripts/scope clear` | 解除 scope enforcement | 不需要時 | Custom |
| `bash .claude/scripts/scope show` | 顯示當前 scope 狀態 | 任何時候 | Custom |

---

## Section 2: Actor Reference — 誰是誰

本 template 中的「執行者」分為 **3 大類 6 種**：

### 2.1 Main Claude

| 維度 | 值 |
|---|---|
| 類型 | **Persistent**（你直接對話的 Claude，跨整段對話保有 context） |
| Isolation | session 的 cwd（你開 Claude Code 的目錄） |
| Model | Session 預設 |
| Memory | conversation history |
| 用在 | 全部 stage 的協調；Phase 1-3 dialogue（spec/plan/tasks）；不寫實作 code 也不寫測試 |

main Claude 的工作是「協調」與「對話」，**重活外包給 subagent**。

### 2.2 自家 Named Agents（在 `.claude/agents/` 定義）

#### task-executor.md

| 維度 | 值 |
|---|---|
| 類型 | **Ephemeral**（每次 dispatch 都 fresh，用完即棄） |
| Isolation | `isolation: worktree`（自動 worktree 隔離） |
| Model | `opus` |
| Tools | Read, Edit, Write, Grep, Glob, Bash |
| Memory | 無（不跨 task 記憶） |
| **用在** | **僅 `/bugfix` Phase 3a**。Superpowers code flow 不使用 task-executor，而是用自帶的 implementer-prompt（見 2.4）|

> **重要**：很多人會以為 Code 新功能流程也用 task-executor。**沒有**。Superpowers 的 subagent-driven-development 用自己的 prompt-template subagents（見 2.4）。task-executor 只在 `/bugfix` Phase 3 出現。

#### code-reviewer.md

| 維度 | 值 |
|---|---|
| 類型 | **Ephemeral**（每次 dispatch fresh） |
| Isolation | 無（read-only） |
| Model | `inherit` |
| Tools | inherit（無明確限制） |
| Memory | 無 |
| **用在** | **僅 `/bugfix` Phase 3b/4 + `/write-document` Phase 4c/5**。Superpowers code flow 用 spec-reviewer + code-quality-reviewer prompts，不用這個 named agent |

兩階段 review：(1) plan alignment, (2) code quality。

#### writer.md

| 維度 | 值 |
|---|---|
| 類型 | **Persistent**（跨章節保有累積的術語、語氣、風格 context） |
| Isolation | 無（不開 worktree） |
| Model | `opus` |
| Tools | Read, Write, Grep, Glob, Bash |
| Memory | 無（但 persistent context 累積）|
| **用在** | **僅 `/write-document` Phase 4a** |

文件撰寫之所以 **persistent** 而非 ephemeral，是因為跨章節需要術語一致、敘事連貫，fresh subagent 會產生風格漂移。

#### verifier.md

| 維度 | 值 |
|---|---|
| 類型 | **Persistent** |
| Isolation | 無（read-only verification） |
| Model | `opus` |
| Tools | Read, Grep, Glob, Bash（**無 Write/Edit**）|
| Memory | **`memory: project`**（跨 session 累積 verification patterns） |
| **用在** | **僅 `/write-document` Phase 4b** |

verifier 做事實查核、cross-reference、術語一致檢查。它**不能改檔案**，只標註問題（JSON output schema）。`memory: project` 讓它跨 session 記住 recurring issue。

### 2.3 Superpowers Prompt-Template Subagents

當 `subagent-driven-development` skill 執行時，它會 dispatch **3 種 ephemeral subagent per task**，每種用一個 prompt 模板檔：

| Subagent role | Prompt file | 用在 task 流程 |
|---|---|---|
| **implementer** | `.claude/skills/subagent-driven-development/implementer-prompt.md` | 寫 code + tests + commits + self-review |
| **spec-reviewer** | `.claude/skills/subagent-driven-development/spec-reviewer-prompt.md` | 確認 implementation 符合 plan/spec |
| **code-quality-reviewer** | `.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md` | review code quality（複用 `code-reviewer.md` agent 的 prompt 內容）|

這些**不是** named agents — 是 dispatch 給 generic subagent 的 prompt 模板。流程：

```
implementer → 完成 task → 回傳 status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED)
   ↓ DONE
spec-reviewer → 確認符合 spec? → FAIL → implementer 修 → re-review
   ↓ PASS
code-quality-reviewer → 確認品質? → FAIL → implementer 修 → re-review
   ↓ PASS
next task
```

每次 dispatch 都是 fresh subagent，用 worktree 隔離（由 `using-git-worktrees` 管理）。

### 2.4 Actor 速查表

| Actor | 類型 | Worktree | Memory | 用在 stage |
|---|---|---|---|---|
| main Claude | persistent | session cwd | conversation | 全部 |
| task-executor (named) | ephemeral | ✓ | - | **僅 /bugfix Phase 3a** |
| code-reviewer (named) | ephemeral | - | - | **僅 /bugfix Phase 3b/4 + /write-document Phase 4c/5** |
| writer (named) | **persistent** | - | - | **僅 /write-document Phase 4a** |
| verifier (named) | **persistent** | - | **project** | **僅 /write-document Phase 4b** |
| implementer (Superpowers prompt) | ephemeral | ✓（via using-git-worktrees）| - | **僅 subagent-driven-development** |
| spec-reviewer (Superpowers prompt) | ephemeral | ✓ | - | **僅 subagent-driven-development** |
| code-quality-reviewer (Superpowers prompt) | ephemeral | ✓ | - | **僅 subagent-driven-development** |

**重要對應**：
- 「Code 新功能」流程的 task 執行者**不是** task-executor，是 Superpowers 的 implementer + spec-reviewer + code-quality-reviewer 三個 prompt 模板
- 「Bug 修復」流程才用 task-executor + code-reviewer named agent
- 「文件專案」用 writer + verifier + code-reviewer

---

## Section 3: Hook 完整參考

本 template 註冊 **9 個 hooks**（含 1 個 git native commit-msg hook 由 pre-commit framework 提供）。
全部都會「優雅退化」：jq 缺失 → 退為 no-op；state file 不存在 → 不擋。

### 3.1 UserPromptSubmit → `skill-router.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `UserPromptSubmit` |
| 註冊在 | `.claude/settings.json` |
| Script | `.claude/hooks/skill-router.sh` |
| stdin schema | `{ session_id, hook_event_name: "UserPromptSubmit", prompt, ... }` |
| 能否 block | 是（透過 `decision: block`），但**我們的 script 不擋**，只 inject hint |
| 觸發頻率 | 每次使用者送 prompt |
| 行為 | 1. 讀 `.prompt`<br>2. 長度 < 10 字 → exit 0<br>3. 命中 `negative_keywords`（typo / 小改 / quick / etc.） → exit 0<br>4. 命中正向 rule → output `hookSpecificOutput.additionalContext` 注入 hint |
| Rules 來源 | `.claude/skill-rules.json` |
| 退化條件 | jq 缺失 → no-op；rules file 缺失 → no-op |

### 3.2 PreToolUse (Edit\|Write) → `branch-enforce.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `PreToolUse` with matcher `Edit|Write` |
| 註冊在 | `.claude/settings.json` |
| Script | `.claude/hooks/branch-enforce.sh` |
| stdin schema | `{ tool_name, tool_input.file_path, ... }` |
| 能否 block | **是**，輸出 `hookSpecificOutput.permissionDecision: deny` |
| 觸發頻率 | 每次 Edit/Write tool call（含 main Claude 與 subagent 內部）|
| 行為 | 讀 `git branch --show-current`：<br>- `main` / `master` → **deny**<br>- `feat/*` / `chore/*` / `docs/*` / `bugfix/*` → allow<br>- 其他 → **deny** |
| 退化條件 | jq 缺失 → no-op；非 git repo → allow |

### 3.3 PreToolUse (Edit\|Write) → `scope-enforce.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `PreToolUse` with matcher `Edit|Write` |
| 註冊在 | `.claude/settings.json`（與 branch-enforce 並列） |
| Script | `.claude/hooks/scope-enforce.sh` |
| stdin schema | `{ tool_name, tool_input.file_path, ... }` |
| 能否 block | **是**（opt-in），輸出 `permissionDecision: deny` |
| 觸發頻率 | 每次 Edit/Write tool call（含 subagent）|
| 行為 | 1. 若 `.claude/state/phase.json` 不存在 → exit 0（**預設關閉**）<br>2. 讀 scope_paths<br>3. 待編輯檔案路徑符合任一 scope path → allow<br>4. 否則 → **deny** with reason |
| 啟用方式 | `bash .claude/scripts/scope set <path>...` |
| 解除方式 | `bash .claude/scripts/scope clear` |
| 退化條件 | jq 缺失 → no-op；state file 不存在 → no-op |

### 3.4 PostToolUse (Edit) → `auto-format.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `PostToolUse` with matcher `Edit` |
| Script | `.claude/hooks/auto-format.sh` |
| stdin schema | `{ tool_input.file_path, tool_response.success, ... }` |
| 能否 block | 否（PostToolUse 無法 deny） |
| 觸發頻率 | 每次成功 Edit 後 |
| 行為 | 讀 `.tool_input.file_path`，依 `/setup` 啟用的語言跑 formatter |
| 預設狀態 | **全部語言註解掉** — 跑 `/setup` 時依 Step 3 取消對應註解 |
| 支援語言 | JS/TS（prettier）、Python（ruff）、Go（gofmt）、Rust（rustfmt）、C/C++（clang-format）、SystemVerilog（verible）|
| **不支援** | Markdown、JSON、YAML、其他 |
| 退化條件 | jq 缺失 → no-op；空 file_path → no-op |

### 3.5 Stop → `stop-verify.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `Stop` |
| Script | `.claude/hooks/stop-verify.sh` |
| 能否 block | **是**（top-level `decision: block`），預設 **advisory only** 不 block |
| 觸發頻率 | 每次 Claude 完成回覆後 |
| 行為 | 1. `git diff --name-only HEAD`（或 fresh repo 用 `--cached`）<br>2. 無變更 → exit 0<br>3. 有變更 → 跑 lint/typecheck（**預設全註解**）<br>4. opt-in blocking 段落（預設註解）：test fail 時 `decision: block` |
| 啟用方式 | `/setup` Step 3，或手動 uncomment script 內的語言指令 |

### 3.6 Notification → `notify.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `Notification` |
| Script | `.claude/hooks/notify.sh` |
| stdin schema | `{ message, ... }` |
| 能否 block | 否 |
| 觸發頻率 | 當 Claude 需要使用者注意時（permission prompt、idle、auth、elicitation） |
| 行為 | 1. 讀 `.message`<br>2. 跑 `osascript display notification`（macOS）<br>3. 寫到 `.claude/logs/notifications.log` |
| Linux | 註解掉的 `notify-send` |
| Windows | 無原生通知，仰賴 log fallback |

### 3.7 SubagentStart → `subagent-start-log.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `SubagentStart` |
| Script | `.claude/hooks/subagent-start-log.sh` |
| stdin schema | `{ session_id, agent_id, agent_type, ... }` |
| 能否 block | 是，但**我們不擋** |
| 觸發頻率 | 每次 subagent dispatch 開始 |
| 行為 | append JSON line 到 `.claude/logs/agent-activity.jsonl`：`{timestamp, event:"START", agent_type, agent_id}` |

### 3.8 SubagentStop → `subagent-stop-gate.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `SubagentStop` |
| Script | `.claude/hooks/subagent-stop-gate.sh` |
| stdin schema | `{ agent_id, agent_type, ... }` |
| 能否 block | 是，但**我們不擋** |
| 觸發頻率 | 每次 subagent 完成 |
| 行為 | 1. append STOP line 到 jsonl<br>2. `osascript display notification` 桌面通知 |

### 3.9 WorktreeCreate → `worktree-enforce.sh`

| 欄位 | 值 |
|---|---|
| Hook event | `WorktreeCreate` |
| Script | `.claude/hooks/worktree-enforce.sh` |
| stdin schema | `{ branch, worktree_path, ... }` |
| 能否 block | **是**，輸出 top-level `decision: block` |
| 觸發頻率 | 每次 git worktree 建立 |
| 行為 | 接受 4 種 pattern：<br>- `feat/{name}/T00X`（custom flow）<br>- `feat/bugfix-{id}/fix`（custom bugfix）<br>- `feat/bugfix-{id}/T00X`（custom bugfix sub-task）<br>- `feature/*`（Superpowers vendored 預設）<br>**Block**：`feat/*` 但不符合 sub-pattern（防誤）<br>**Allow（不擋）**：完全不同 prefix（如 `experiment/foo`） |
| 退化條件 | jq 缺失 → no-op；空 branch → no-op |

### 3.10 (extra) Git native commit-msg hook（由 pre-commit framework 安裝）

| 欄位 | 值 |
|---|---|
| Hook | git 原生 `commit-msg` |
| 註冊在 | `.git/hooks/commit-msg`（由 `pre-commit install` 寫入）|
| 配置在 | `.pre-commit-config.yaml` |
| Tools | `compilerla/conventional-pre-commit` + `gitleaks/gitleaks` |
| 觸發頻率 | 每次 `git commit` |
| 行為 | 1. **conventional-pre-commit**：驗證 commit message 格式（type(scope): subject）<br>2. **gitleaks**：掃 staged diff 找已知 secret pattern |
| Block | 任一 fail → commit 整個被擋 |
| 啟用方式 | `bash bootstrap.sh` 自動嘗試裝；或手動 `pipx install pre-commit && pre-commit install` |
| 合法 type | `feat fix docs style refactor test chore perf ci spec plan tasks draft verify` |

### 3.11 (extra) settings.json `permissions.deny`

不是 hook，但同層 enforcement，列在這方便對照。

| 欄位 | 值 |
|---|---|
| 註冊在 | `.claude/settings.json` `permissions.deny` |
| 機制 | Claude Code 內建，hard deny 永遠優先 |
| 觸發頻率 | 每次 Bash tool call |
| Deny list | `rm -rf *`、`git push --force*`、`git push * main`、`git push * master`、`git checkout main && merge*`、`git checkout master && merge*`、`git branch -D main/master`、`git rebase * main/master`、`git reset --hard origin*`、`git clean -fdx*`、`git checkout --force*`、`git stash drop*`、`git stash clear*` |
| Block | 任一命中 → 整個 Bash 被擋，不可繞過 |

---

## Section 4: Skill 完整參考

本 template 共 **18 個 skills**：14 個 vendored from Superpowers + 4 個 custom（含 1 個 vendored 自 karpathy）。

### 4.1 Vendored from obra/superpowers (14)

#### brainstorming
- **來源**：Vendored Superpowers, MIT
- **Trigger description**：「You MUST use this before any creative work — creating features, building components, adding functionality, or modifying behavior.」
- **Auto-invocable**：是（model 自動偵測 + skill-router hint 強化）
- **Input**：使用者需求描述 + project context
- **Output path**：`.specify/specs/YYYY-MM-DD-<topic>-design.md`（行 29、111）
- **Commit**：「commit the design document」（行 114），**不強制** prefix
- **Branch**：**不自動建** branch；使用者要先在 branch 上
- **Dispatch chain**：→ writing-plans（行 32, 66）
- **Gates**：**HARD-GATE**（行 12-13）— 未經使用者 approve design 不得寫任何 code
- **Failure**：使用者 reject → revise → re-present

#### writing-plans
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「Use when you have a spec or requirements for a multi-step task, before touching code」
- **Auto-invocable**：是
- **Output path**：`.specify/plans/YYYY-MM-DD-<feature-name>.md`（行 18）
- **Commit**：plan 內 task 範例用 `feat: add specific feature`（行 102），**不強制**統一 prefix
- **Dispatch chain**：→ subagent-driven-development OR executing-plans（行 138-153，使用者選）
- **Gates**：placeholder scan（行 128）
- **Failure**：plan 不完整 → fix inline

#### executing-plans
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「executing implementation plan with review checkpoints in a separate session」
- **Auto-invocable**：是（manual-only 推薦：「Tell your human partner that Superpowers works much better with access to subagents」行 11）
- **執行模式**：**inline**（不 spawn subagent，main Claude 自己跑）
- **Required**：`using-git-worktrees` 必須先建 worktree（行 68）
- **Failure**：blocker → ask human

#### subagent-driven-development
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「executing implementation plans with independent tasks in the current session」
- **Auto-invocable**：是
- **Required**：`using-git-worktrees`（行 268）
- **Dispatch**：**3 subagents per task**：
  - implementer（uses `./implementer-prompt.md`，行 122）
  - spec-reviewer（uses `./spec-reviewer-prompt.md`，行 123）
  - code-quality-reviewer（uses `./code-quality-reviewer-prompt.md`，行 124）
- **Status handling**（行 102-117）：DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
- **Two-stage review per task**（行 71-78）：spec 然後 quality
- **Retry**：BLOCKED → 升級 model 重 dispatch（行 114-117）
- **Dispatch chain**：→ finishing-a-development-branch（行 64）

#### test-driven-development
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「implementing any feature or bugfix, before writing implementation code」
- **Auto-invocable**：是
- **Iron Law**：「NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST」（行 34-35）
- **被誰讀**：implementer subagent、task-executor agent、main Claude（依情境）
- **Failure**：寫 test 結果直接 pass → fix 該 test，因為它沒測對東西

#### systematic-debugging
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「encountering any bug, test failure, or unexpected behavior, before proposing fixes」
- **Auto-invocable**：是
- **4-phase 強制順序**（行 48）：observation → hypothesis → test → repair
- **Hard gate**：≥3 fix attempts → 必須質疑架構假設（行 196-211）
- **Dispatch chain**：→ test-driven-development（行 179）→ verification-before-completion（行 287）

#### requesting-code-review
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「completing tasks, implementing major features, or before merging」
- **Dispatch**：透過 Task tool spawn code-reviewer subagent（uses `./code-reviewer.md` template，與 root level `.claude/agents/code-reviewer.md` 不同檔）

#### receiving-code-review
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「receiving code review feedback, before implementing suggestions」
- **Process**：Understand → Verify → Evaluate → Respond（行 19-23）
- **Hard gate**：unclear feedback → block 直到澄清（行 40-48）

#### verification-before-completion
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「about to claim work is complete, fixed, or passing, before committing or creating PRs」
- **Iron Law**：「NO CLAIMS WITHOUT FRESH VERIFICATION」（行 16-22）
- **要求**：跑驗證指令並確認 output 才能宣稱完成

#### dispatching-parallel-agents
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「2+ independent tasks that can be worked on without shared state」
- **Dispatch**：one subagent per problem domain（行 66-74）
- **Conflict 偵測**：跑全套 test suite（行 183）

#### using-git-worktrees
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「starting feature work that needs isolation from current workspace」
- **建立位置**：`.worktrees/`（首選）或 `worktrees/` 或 `~/.config/superpowers/worktrees/`（行 17-95）
- **建立指令**：`git worktree add "$path" -b "$BRANCH_NAME"`（行 97）
- **Branch 命名範例**：`feature/auth`（行 185）— **不強制** pattern，使用者可改
- **Safety gate**：必須先驗證目錄已被 .gitignore（行 53-68）

#### finishing-a-development-branch
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「implementation complete, all tests pass, decide how to integrate」
- **4 Options**：merge / PR via `gh pr create` / leave / discard
- **Test gate**：跑 test 確認綠燈才進入 options（行 18-38）
- **Cleanup worktree**：option 1, 2, 4 自動清；option 3 不清

#### using-superpowers
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「start of any conversation」
- **作用**：強制 main Claude 在回答前先檢查 skill 適用性
- **Iron Law**：「Invoke Skill tool before response」（行 45-75）

#### writing-skills
- **來源**：Vendored Superpowers, MIT
- **Trigger**：「creating new skills, editing existing skills, or verifying skills work」
- **方法**：Apply TDD to skill writing（pressure scenarios with subagents）
- **依賴**：必須先了解 test-driven-development（行 20）
- **Output**：`~/.claude/skills/<skill-name>/SKILL.md`

### 4.2 Custom Skills (4)

#### setup
- **來源**：Custom（自家）
- **Frontmatter**：`disable-model-invocation: true`（**只能** `/setup` 手動觸發）
- **Trigger**：「first-run project setup wizard」
- **9 個 step**：專案類型 / CLAUDE.md / formatter / agent tools / skills / MCP / Spec Kit + plugins / 自訂 agents / 總結
- **每 step 都有 ★ APPROVE gate**
- **Output paths**：`.specify/{memory,specs,bugs}/`、`CLAUDE.md`、`.claude/hooks/auto-format.sh`（uncommented）

#### bugfix
- **來源**：Custom（自家）
- **Frontmatter**：`disable-model-invocation: true`
- **Trigger**：「bug fix workflow for code projects with 4 phases」
- **4 Phases**：
  - **Phase 1: Report**（main Claude，無 subagent）→ `.specify/bugs/{bug-id}/report.md` → commit `docs: {bug-id} — report` → ★ APPROVE
  - **Phase 2: Analyze**（main Claude 讀 systematic-debugging skill）→ `.specify/bugs/{bug-id}/analysis.md` → commit `docs: {bug-id} — root cause analysis` → ★ APPROVE
  - **Phase 3: Fix**：
    - 3a. dispatch **task-executor**（fresh ephemeral, worktree `feat/bugfix-{id}/fix`）→ TDD Iron Law → commits `test(scope): [BUG-{id}]` + `fix(scope): [BUG-{id}]`
    - 3b. dispatch **code-reviewer**（fresh ephemeral, two-stage）→ PASS / FAIL
    - Retry：FAIL → 新 task-executor，最多 3 次
  - **Phase 4: Verify**（dispatch fresh code-reviewer）→ `.specify/bugs/{bug-id}/verification.md` → commit `docs: {bug-id} — verification report` → ★ APPROVE
- **Bug-id 格式**：`BUG-yyyymmdd-nnn`
- **Commit prefix 強制**：是
- **Branch**：`feat/bugfix-{bug-id}` 從 main 建立

#### write-document
- **來源**：Custom（自家）
- **Frontmatter**：`disable-model-invocation: true`
- **Trigger**：「Spec-driven workflow for DOCUMENT projects (specs, patents, technical reports)」
- **5 Phases**：
  - **Phase 1: Specification**（main Claude）→ `.specify/specs/{name}/spec.md` → commit `spec: doc-{name} — requirements` → ★ APPROVE
  - **Phase 2: Structure Plan**（main Claude）→ `.specify/specs/{name}/plan.md`（章節 + 術語表） → commit `plan: doc-{name} — structure and terminology` → ★ APPROVE
  - **Phase 3: Chapter Tasks**（main Claude）→ `.specify/specs/{name}/tasks.md` → commit `tasks: doc-{name} — task decomposition` → ★ APPROVE
  - **Phase 4: Drafting Cycle**（per chapter）：
    - 4a. dispatch **writer**（**persistent**）→ `.specify/specs/{name}/drafts/T00X-{slug}.md` → commit `draft(doc): [T00X]`
    - 4b. dispatch **verifier**（**persistent, memory: project**）→ JSON report → commit `verify(doc): [T00X]`
    - 4c. dispatch **code-reviewer**（fresh ephemeral, two-stage）→ PASS / FAIL
    - Retry：FAIL → **同 writer** 修（保留 context），最多 3 次
  - **Phase 5: Final Review**（code-reviewer + 使用者）→ `.specify/specs/{name}/final-review.md` → commit `docs: doc-{name} — final review` → ★ APPROVE
- **APPROVE gates**：4（spec / plan / tasks / final）
- **Worktree**：**無**（章節 sequential）
- **TDD**：**無**（文件無 test 概念）
- **與 Code flow 根本差異**：persistent agents、無 worktree、無 TDD、跨章節 context 持續

#### karpathy-guidelines
- **來源**：Vendored from forrestchang/andrej-karpathy-skills, MIT
- **Frontmatter**：`license: MIT`，無 `disable-model-invocation`（可被 model auto-invoke）
- **Trigger**：「writing, reviewing, or refactoring code」
- **內容**：4 條準則 — Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution
- **Output**：無檔案（純行為準則）
- **被誰參考**：task-executor agent body 行 29 明確要求遵守

---

## Section 5: 9 個 Stage 詳細卡片

每張卡片強制 11 個欄位，所有事實對應 Section 2/3/4 的 reference，無 hallucination。

---

### Stage 0: 第一次拿到 template

| 欄位 | 內容 |
|---|---|
| **觸發** | `gh repo create my-app --template changlukas/your-project --clone` → `cd my-app` → `bash bootstrap.sh` |
| **執行者** | 使用者 + bootstrap.sh script（**Claude Code 還沒啟動**）|
| **隔離** | N/A |
| **載入 skills** | 無（Claude 還沒跑）|
| **Hook 觸發** | 無 |
| **產出檔案** | 目錄：`.specify/{memory,specs,bugs}/`、`.claude/{logs,agent-memory,state}/`<br>權限：`.claude/hooks/*.sh` 與 `.claude/scripts/*` 標 `+x` |
| **Commit** | 無（bootstrap 不 commit）|
| **APPROVE gates** | 無互動 |
| **失敗 / retry** | jq 缺失 → exit 1 + 印安裝指引（macOS / Linux / Windows）<br>git 缺失 → exit 1<br>pre-commit 缺失 → WARN（可選）|
| **完成條件** | summary block 印 `Status: READY` |
| **範例** | 見下方 |

```
$ bash bootstrap.sh
[bootstrap] creating dirs...
[bootstrap] marking hook scripts executable...
[bootstrap] checking required tools...
  OK: git present
  OK: jq present
[bootstrap] validating settings.json...
  OK
[bootstrap] checking pre-commit framework...
  OK: pre-commit hooks installed

=== bootstrap summary ===
  ✓ git
  ✓ jq
  ✓ settings
  ✓ pre-commit

Status: READY
Next: claude  →  /setup  (interactive setup wizard)
```

**Gotchas**：
- jq 是 hook hard requirement，沒裝會 exit 1（不是 warn）
- pre-commit 是 optional（commit message 驗證少了 而已）
- bootstrap 自身不建 git remote；Stage 0.5 後使用者自行 `git remote add`

---

### Stage 0.5: `/setup` 互動式 wizard

| 欄位 | 內容 |
|---|---|
| **觸發** | `claude` → `/setup` |
| **執行者** | main Claude + setup skill |
| **隔離** | session cwd |
| **載入 skills** | `setup`（custom，`disable-model-invocation: true`，**只能**手動觸發） |
| **Hook 觸發** | UserPromptSubmit → skill-router 命中 `/setup` 字元（probably skip 因為 < 10 字）|
| **產出檔案** | `CLAUDE.md`（如選擇生成）；`.claude/hooks/auto-format.sh` 取消對應語言註解 |
| **Commit** | 無（wizard 結束時建議 `chore: initialize project configuration` 但要使用者自跑）|
| **APPROVE gates** | 9 個 step 各一個 gate |
| **失敗** | 任 step 跳過則影響後續預設 |
| **完成條件** | Step 9 顯示總結 + 下一步指令 |
| **範例** | wizard 對話流（每 step 一問一答）|

**9 個 steps**：
1. 專案類型（Code / Document / Both）
2. CLAUDE.md 內容生成
3. Formatter 設定（uncomment auto-format.sh 對應語言）
4. Agent tool 權限調整（task-executor / writer 加 Bash 指令）
5. Skills（可選新增自訂 skill）
6. MCP（可選連接外部工具）
7. Spec Kit + 推薦 plugins（specify-cli / tdd-guard / plannotator / pre-commit）
8. 自訂 agents（可選）
9. 總結

**Gotchas**：
- setup skill 是 disable-model-invocation，必須手動 `/setup`
- 9 個 step 全程互動，無法 batch 帶入答案

---

### Stage 1: Code 專案 — 新功能（Superpowers flow）

> **這是最複雜的 stage**。涉及 5 個 vendored skills + main Claude + 3 種 prompt-template subagents。

| 欄位 | 內容 |
|---|---|
| **觸發** | 使用者描述需求（命中 skill-router brainstorming keyword 如「新功能」「加一個」「implement」）|
| **執行者** | 主：main Claude（dialogue + plan）<br>輔：每個 task 由 **3 個 ephemeral subagents** 處理（implementer + spec-reviewer + code-quality-reviewer，via prompt template）<br>**不使用** task-executor / code-reviewer named agent |
| **隔離** | 每個 task 由 `using-git-worktrees` 建立 worktree（branch 預設 `feature/<name>`，由 main Claude 決定具體名稱）|
| **載入 skills（時序）** | 1. brainstorming（HARD-GATE design）<br>2. writing-plans（轉 plan）<br>3. subagent-driven-development OR executing-plans（使用者選）<br>4. using-git-worktrees（每 task 開 worktree）<br>5. test-driven-development（implementer 內讀）<br>6. verification-before-completion（implementer 內讀）<br>7. finishing-a-development-branch（最後）|
| **Hook 觸發點** | UserPromptSubmit → skill-router 注入 brainstorming hint<br>PreToolUse (Edit/Write) → branch-enforce + scope-enforce<br>WorktreeCreate → worktree-enforce（接受 `feature/*`）<br>SubagentStart → log<br>SubagentStop → log + 桌面通知<br>PostToolUse (Edit) → auto-format（若啟用）<br>Stop → stop-verify（advisory）|
| **產出檔案** | spec：`.specify/specs/YYYY-MM-DD-<feature>-design.md`（brainstorming 行 29）<br>plan：`.specify/plans/YYYY-MM-DD-<feature>.md`（writing-plans 行 18）<br>code/test：在各 task 的 worktree 內 |
| **Commit** | vendored skills **不強制**統一 prefix；writing-plans 範例用 `feat: ...`（行 102）<br>**pre-commit framework（若啟用）會強制** conventional commit 格式 |
| **APPROVE gates** | 1. **brainstorming HARD-GATE**：未經 design approval 不寫 code（強制）<br>2. plan 完成後 main Claude 等使用者 review（implicit）<br>3. **每個 task 由 spec-reviewer + code-quality-reviewer 自動 gate**（不需使用者）<br>4. finishing-a-development-branch 4 options 由使用者選 |
| **失敗 / retry** | implementer subagent 回 BLOCKED → 升級 model 重 dispatch（subagent-driven-development 行 114-117）<br>spec-reviewer / code-quality-reviewer FAIL → implementer 修 → re-review |
| **完成條件** | finishing-a-development-branch 完成所選 option（PR / merge / discard）|

**範例對話**（精簡版）：
```
> 我想加一個 JWT 驗證來保護 API endpoints

[skill-router 注入 brainstorming hint]

Claude: 這像是新功能。我先用 brainstorming skill 對話釐清。
   1. 目前有多少 endpoints?
   2. token 存哪？(localStorage / cookie / header)
   3. expire / refresh 機制？

> 12 endpoints, httpOnly cookie, 15min access + 7d refresh

Claude: [兩個方案，建議方案 B...]

> B

Claude: [寫 design 到 .specify/specs/2026-04-15-jwt-auth-design.md, commit]
   ★ HARD-GATE: 請 review design，approve 後我繼續。

> approve

Claude: 跑 writing-plans skill...
   [寫到 .specify/plans/2026-04-15-jwt-auth.md]
   Plan 完成。要用 subagent-driven-development（同 session, 推薦）還是 executing-plans（另開 session）?

> subagent-driven

Claude: 跑 using-git-worktrees... 建立 worktree feature/jwt-auth at .worktrees/jwt-auth/
   [WorktreeCreate hook 通過 — feature/* 接受]

   開始 task 1 of 5: ...
   Dispatch implementer subagent (./implementer-prompt.md)
   [SubagentStart logged]
   ...
   Implementer DONE. Dispatch spec-reviewer (./spec-reviewer-prompt.md)
   spec-reviewer PASS. Dispatch code-quality-reviewer (./code-quality-reviewer-prompt.md)
   code-quality-reviewer PASS.
   [SubagentStop logged + desktop notification]

   Task 1/5 complete. Continuing task 2/5...
   ...
   All 5 tasks complete. Running finishing-a-development-branch skill.

   Tests: 47 passing, 0 failures
   Options:
     1. Merge to main locally
     2. Push branch and create PR via gh
     3. Leave as-is for review
     4. Discard

> 2

Claude: gh pr create ... PR opened: https://github.com/.../pull/42
```

**Gotchas**：
- branch 命名是 `feature/<name>`（vendored 預設），**不是** `feat/<name>/T00X`
- task-executor agent 名稱在這條 flow **完全不會出現**
- HARD-GATE 對小 feature 也適用，無 escape 機制
- 使用 subagent-driven-development 推薦勝過 executing-plans（後者 inline，無 subagent 加速）

---

### Stage 2: Bug 修復（/bugfix custom flow）

| 欄位 | 內容 |
|---|---|
| **觸發** | 使用者描述 bug（命中 skill-router bugfix keyword）|
| **執行者** | Phase 1-2: main Claude<br>Phase 3a: **task-executor agent**（fresh ephemeral, isolation: worktree）<br>Phase 3b/4: **code-reviewer agent**（fresh ephemeral）|
| **隔離** | Phase 3 worktree branch `feat/bugfix-{id}/fix`（符合 worktree-enforce pattern）|
| **載入 skills** | bugfix（custom orchestrator）<br>systematic-debugging（Phase 2 main Claude 讀）<br>test-driven-development（Phase 3 task-executor 讀）<br>karpathy-guidelines（Phase 3 task-executor 讀）|
| **Hook 觸發點** | 同 Stage 1 + WorktreeCreate 接受 `feat/bugfix-*/fix` |
| **產出檔案** | `.specify/bugs/{bug-id}/{report,analysis,verification}.md` |
| **Commit prefix** | **強制**：<br>- Phase 1: `docs: {bug-id} — report`<br>- Phase 2: `docs: {bug-id} — root cause analysis`<br>- Phase 3 task-executor: `test(scope): [BUG-{id}] ...` + `fix(scope): [BUG-{id}] ...`<br>- Phase 4: `docs: {bug-id} — verification report` |
| **APPROVE gates** | 3 個（Phase 1 / 2 / 4 後）|
| **失敗 / retry** | Phase 3 max 3 次新 task-executor dispatch；3 次 fail 暫停呈報 |
| **完成條件** | Phase 4 verification approved → 開 PR `feat/bugfix-{id}` → main |

**範例對話**：
```
> 登入 endpoint deploy 後一直回 500，看起來是 race condition

[skill-router 注入 bugfix hint]

Claude: 看起來是 bug，跑 /bugfix。

[Phase 1 - Report]
讀了 src/auth/login.ts...
寫 report.md：BUG-20260415-001
   - Symptom: 500 on POST /login
   - Repro: 1000 concurrent requests
   - Severity: critical
建立 feat/bugfix-001 branch, commit `docs: BUG-20260415-001 — report`
★ approve report?

> approve

[Phase 2 - Analyze]
讀 systematic-debugging skill...
Root cause: bcrypt.compare 在 race condition 下 await 漏寫
寫 analysis.md, commit
★ approve analysis?

> approve

[Phase 3 - Fix]
建立 worktree feat/bugfix-001/fix [WorktreeCreate hook ✓]
Dispatch task-executor... [SubagentStart logged]
   - 寫 regression test (RED)
   - 寫 fix (GREEN)
   - commits: test + fix
[SubagentStop logged + notification]

Dispatch code-reviewer (two-stage)... PASS
Merge worktree → feat/bugfix-001

[Phase 4 - Verify]
Dispatch code-reviewer... 
   - regression test: PASS
   - existing test suite: PASS
寫 verification.md, commit
★ approve final?

> approve

PR opened: feat/bugfix-001 → main
```

**Gotchas**：
- bug-id 命名是 `BUG-yyyymmdd-nnn`
- task-executor 在這 stage 用，**不在** Stage 1 用
- Phase 3 retry 是 dispatch 新 task-executor，不是同一個 retry

---

### Stage 3: 文件專案（/write-document custom flow）

| 欄位 | 內容 |
|---|---|
| **觸發** | 使用者描述文件需求（命中 skill-router write-document keyword 如「專利」「技術報告」）|
| **執行者** | Phase 1-3: main Claude<br>Phase 4a: **writer agent**（**persistent**，跨章節保 context）<br>Phase 4b: **verifier agent**（**persistent, memory: project**）<br>Phase 4c/5: **code-reviewer agent**（fresh ephemeral）|
| **隔離** | **無 worktree**（章節 sequential，跨章 context 重要）|
| **載入 skills** | write-document（custom orchestrator）<br>可選 verification-before-completion |
| **Hook 觸發點** | UserPromptSubmit → skill-router 注入 write-document hint<br>PreToolUse → branch-enforce<br>SubagentStart/Stop → log + 通知<br>**WorktreeCreate 不觸發**（無 worktree）|
| **產出檔案** | `.specify/specs/{name}/spec.md`<br>`.specify/specs/{name}/plan.md`<br>`.specify/specs/{name}/tasks.md`<br>`.specify/specs/{name}/drafts/T00X-{slug}.md`<br>`.specify/specs/{name}/final-review.md` |
| **Commit prefix** | **強制**：`spec:` `plan:` `tasks:` `draft(doc):` `verify(doc):` `docs:` |
| **APPROVE gates** | 4 個（spec / plan / tasks / final）|
| **失敗 / retry** | Phase 4 retry 是**同 writer**（保留 context），最多 3 次；3 次 fail 暫停呈報 |
| **完成條件** | Phase 5 final review approved → PR |

**5 phases 概覽**：
1. **Spec**: dialogue → spec.md → APPROVE
2. **Structure Plan**: 章節 + 術語表 → plan.md → APPROVE
3. **Chapter Tasks**: per-chapter task with boundary → tasks.md → APPROVE
4. **Drafting Cycle**（per chapter）：writer → verifier → code-reviewer → next chapter or retry
5. **Final Review**: 整份終審 → APPROVE → PR

**Gotchas**：
- 跟 Code flow **完全不同**：persistent agents、無 worktree、無 TDD
- writer FAIL retry 用同一個 writer（保留 context），不像 task-executor 是 fresh dispatch
- verifier 的 `memory: project` 讓它跨 session 累積 verification patterns

---

### Stage 4: 小型編輯（typo / comment / rename）

| 欄位 | 內容 |
|---|---|
| **觸發** | 使用者描述小修，prompt 含 negative keyword（typo / 小改 / quick / 註解 / etc.）|
| **執行者** | main Claude（無 subagent dispatch）|
| **隔離** | session cwd |
| **載入 skills** | 無強制 |
| **Hook 觸發點** | UserPromptSubmit → skill-router 命中 negative keyword → **skip**（不注入 hint）<br>PreToolUse (Edit/Write) → branch-enforce **仍然執行**<br>PreToolUse → scope-enforce（若啟用）<br>PostToolUse → auto-format（若啟用該語言）<br>Stop → stop-verify |
| **產出檔案** | 直接編輯 source |
| **Commit** | 使用者自行 commit；pre-commit framework（若啟用）會驗證格式 |
| **APPROVE gates** | 無 |
| **失敗** | branch 不對 → branch-enforce deny |
| **完成條件** | 修完 + commit |

**範例**：
```
> 修一下 README 裡 "the the" 的 typo

[skill-router 命中 negative keyword `typo` → skip]

Claude: [Edit README.md...]
[branch-enforce: feat/typo-fix ✓ allow]
[auto-format: markdown 不在支援清單 → no-op]
完成。

> commit

Claude: git add README.md && git commit -m "docs: fix typo in README"
[conventional-pre-commit ✓ pass]
[gitleaks ✓ pass]
```

**Gotchas**：
- auto-format.sh **不含 markdown** — 修 README 不會被自動 format
- branch 必須是 `feat/` `chore/` `docs/` `bugfix/` 開頭，否則 branch-enforce 擋
- skill-router 雖跳過，但 PreToolUse hook **仍執行**

---

### Stage 5: 日常 Q&A（不動檔案）

| 欄位 | 內容 |
|---|---|
| **觸發** | 使用者問問題或要求解釋 |
| **執行者** | main Claude |
| **隔離** | session cwd |
| **載入 skills** | 無 |
| **Hook 觸發點** | UserPromptSubmit → skill-router fires 但通常無命中 → 無 hint<br>**無其他 hook 觸發**（Read 不是 Edit）<br>Stop → stop-verify 偵測無變更 → no-op |
| **產出檔案** | 無 |
| **Commit** | 無 |
| **APPROVE gates** | 無 |
| **完成條件** | Claude 回答完問題 |

**範例**：
```
> 解釋一下 src/auth/login.ts 的 flow

Claude: [Read src/auth/login.ts]
[branch-enforce 不觸發 — 沒 Edit/Write tool call]
這個 file 處理 login flow：
  1. ...
  2. ...
```

**Gotchas**：什麼 enforcement 都不會跳出來打擾你。

---

### Stage 6: Opt-in Scope Enforcement

| 欄位 | 內容 |
|---|---|
| **觸發** | 使用者主動跑 `bash .claude/scripts/scope set <path>...` |
| **執行者** | 使用者 + scope-enforce.sh（hook） |
| **隔離** | N/A |
| **載入 skills** | 無 |
| **Hook 觸發點** | 之後**所有 Edit/Write tool call** 都會經 scope-enforce.sh 比對 scope_paths |
| **產出檔案** | `.claude/state/phase.json`（不 commit，gitignored）|
| **Commit** | 無 |
| **APPROVE gates** | 無 |
| **完成條件** | 使用者跑 `bash .claude/scripts/scope clear` 解除 |

**使用情境**：
你在 `feat/jwt-auth` branch 上，task 應該只動 `src/auth/`，但擔心 AI 不小心摸到 `src/api/`。

```bash
# 啟用
$ bash .claude/scripts/scope set src/auth/ tests/auth/
scope set: src/auth/ tests/auth/

# 之後任何 Edit/Write 經 scope-enforce 驗證
# 試圖 Edit src/api/foo.py → 被 deny
# 試圖 Edit src/auth/login.py → 通過

# 解除
$ bash .claude/scripts/scope clear
scope cleared (enforcement disabled)

# 查看
$ bash .claude/scripts/scope show
no scope set (enforcement disabled)
```

**Gotchas**：
- 預設關閉，需明確 opt-in
- state file 在 `.claude/state/`，已 gitignore
- 多人協作時是 per-machine state，不會 sync

---

### Stage 7: 撞 enforcement walls — 反範例參考

當任一 enforcement 擋下你時，這裡是常見情境與修法。

#### 7.1 在 main / master 編輯
```
permission denied: Cannot edit on "main". Create a feat/{name} (or chore/*, docs/*, bugfix/*) branch first.
```
**修**：`git switch -c feat/your-feature`

#### 7.2 在不允許的 branch prefix 編輯
```
permission denied: Branch "experiment-foo" is not allowed for edits. Use feat/*, chore/*, docs/*, or bugfix/* prefix.
```
**修**：rename branch 或開新的 `feat/...` branch

#### 7.3 Worktree 命名違反
```
{
  "decision": "block",
  "reason": "Worktree branch \"feat/foo/bar\" starts with feat/ but missing subtask marker. Use feat/{name}/T00X (custom flow), feat/bugfix-{id}/fix (custom bugfix), or feature/{name} (Superpowers default)."
}
```
**修**：用 canonical naming（`feat/foo/T001`、`feat/bugfix-001/fix`、`feature/foo`）

#### 7.4 Commit message 違反 conventional commit
```
✗ commit-msg
- hook id: conventional-pre-commit
- exit code: 1
Bad commit message, expected pattern: type(scope): subject
```
**修**：用合法 prefix
- 合法：`feat fix docs style refactor test chore perf ci spec plan tasks draft verify`
- 範例：`fix(auth): race condition in login`

#### 7.5 Gitleaks 偵測到 secret
```
gitleaks: WARN secret detected: stripe-api-key
```
**修**：把 secret 移到 `.env`、加入 `.gitignore`、改用 secret manager；revert 該 file 後重 commit

#### 7.6 試圖 git push --force 或 push to main
```
permission denied: Bash(git push --force*)
```
**修**：別這樣做。要 force push 必須先和維護者討論並暫時關掉 deny rule

#### 7.7 試圖 rm -rf
```
permission denied: Bash(rm -rf *)
```
**修**：用更精準的 path（`rm -r specific-dir/`）

#### 7.8 Scope-enforce 擋下 scope 外編輯
```
permission denied: File src/api/foo.py is outside current task scope. Allowed paths: src/auth/ tests/auth/. Run 'bash .claude/scripts/scope set <path>' to update, or 'bash .claude/scripts/scope clear' to disable enforcement.
```
**修**：擴充 scope 或 clear scope：
```bash
bash .claude/scripts/scope set src/auth/ tests/auth/ src/api/
# 或
bash .claude/scripts/scope clear
```

#### 7.9 jq 缺失導致 hooks 失效
**現象**：bootstrap.sh 直接 exit 1
**修**：依平台裝 jq：
- macOS: `brew install jq`
- Linux: `apt-get install jq`
- Windows: `scoop install jq`

#### 7.10 brainstorming HARD-GATE 阻擋了寫 code
```
[brainstorming HARD-GATE active]
Claude: I cannot write code until you approve the design. Here's the design...
```
**修**：review design 並 approve；或顯式打斷說「skip brainstorming」（model 通常會尊重）

---

## Section 6: Cross-stage Matrices

四張矩陣讓你一次看清 hook / skill / agent / file 在哪些 stage 出現。

Stage 簡寫：S0=bootstrap, S0.5=/setup, S1=Code 新功能, S2=/bugfix, S3=/write-document, S4=小型編輯, S5=Q&A, S6=scope, S7=反範例

### 6.1 Hooks × Stages

| Hook | S0 | S0.5 | S1 | S2 | S3 | S4 | S5 | S6 | S7 |
|---|---|---|---|---|---|---|---|---|---|
| skill-router (UserPromptSubmit) | - | fires-skip | **inject hint** | **inject hint** | **inject hint** | fires-skip(neg) | fires-skip(short) | - | - |
| branch-enforce (PreToolUse) | - | - | check feat/* | check bugfix/* | check feat/docs/* | **enforce** | - | - | varies |
| scope-enforce (PreToolUse) | - | - | opt-in | opt-in | opt-in | opt-in | - | **set/clear** | - |
| auto-format (PostToolUse) | - | - | per-language | per-language | - | per-language | - | - | - |
| stop-verify (Stop) | - | - | advisory | advisory | advisory | advisory | no-op | - | - |
| notify (Notification) | - | - | on permission prompt | on permission prompt | on permission prompt | rare | rare | - | - |
| subagent-start-log (SubagentStart) | - | - | **log per task** | **log Phase 3** | **log per chapter** | - | - | - | - |
| subagent-stop-gate (SubagentStop) | - | - | **log + notify** | **log + notify** | **log + notify** | - | - | - | - |
| worktree-enforce (WorktreeCreate) | - | - | **check feature/*** | **check feat/bugfix-*/fix** | - | - | - | - | varies |
| pre-commit (git native commit-msg) | - | - | on commit | on commit | on commit | on commit | - | - | varies |

### 6.2 Skills × Stages

| Skill | 來源 | S0 | S0.5 | S1 | S2 | S3 | S4 | S5 |
|---|---|---|---|---|---|---|---|---|
| setup | custom | - | **drives** | - | - | - | - | - |
| bugfix | custom | - | - | - | **drives** | - | - | - |
| write-document | custom | - | - | - | - | **drives** | - | - |
| karpathy-guidelines | vendor (forrestchang) | - | - | (referenced) | (referenced) | (referenced) | - | - |
| brainstorming | vendor (Superpowers) | - | - | **Phase 1** | - | - | - | - |
| writing-plans | vendor | - | - | **Phase 2** | - | - | - | - |
| executing-plans | vendor | - | - | Phase 3 alt | - | - | - | - |
| subagent-driven-development | vendor | - | - | **Phase 3 (recommended)** | - | - | - | - |
| test-driven-development | vendor | - | - | **inside implementer** | **inside task-executor** | - | - | - |
| systematic-debugging | vendor | - | - | - | **Phase 2** | - | - | - |
| requesting-code-review | vendor | - | - | (alt path) | - | - | - | - |
| receiving-code-review | vendor | - | - | (handle review) | (handle review) | (handle review) | - | - |
| verification-before-completion | vendor | - | - | **inside implementer** | **inside task-executor** | optional | - | - |
| dispatching-parallel-agents | vendor | - | - | optional Wave | - | - | - | - |
| using-git-worktrees | vendor | - | - | **Phase 3 (worktree)** | (Phase 3 worktree) | - | - | - |
| finishing-a-development-branch | vendor | - | - | **Phase 4 (close)** | - | - | - | - |
| using-superpowers | vendor | - | - | meta entry | meta entry | meta entry | meta entry | meta entry |
| writing-skills | vendor | - | - | (only when authoring skills) | - | - | - | - |

### 6.3 Agents × Stages

| Agent | 類型 | S0 | S0.5 | S1 | S2 | S3 | S4 | S5 | S6 |
|---|---|---|---|---|---|---|---|---|---|
| main Claude | persistent | - | ✓ | ✓ all phases | ✓ Phase 1-2 + orchestrate | ✓ Phase 1-3 + orchestrate | ✓ | ✓ | - |
| **task-executor** (named) | ephemeral | - | - | **NEVER** | ✓ Phase 3a | - | - | - | - |
| **code-reviewer** (named) | ephemeral | - | - | **NEVER** | ✓ Phase 3b/4 | ✓ Phase 4c/5 | - | - | - |
| **writer** (named) | persistent | - | - | - | - | ✓ Phase 4a | - | - | - |
| **verifier** (named, memory: project) | persistent | - | - | - | - | ✓ Phase 4b | - | - | - |
| implementer (Superpowers prompt) | ephemeral | - | - | ✓ each task | - | - | - | - | - |
| spec-reviewer (Superpowers prompt) | ephemeral | - | - | ✓ each task review | - | - | - | - | - |
| code-quality-reviewer (Superpowers prompt) | ephemeral | - | - | ✓ each task review | - | - | - | - | - |

**重要對應**（再次強調）：
- Stage 1 (Code 新功能) **不用** task-executor / code-reviewer named agent
- Stage 2 (/bugfix) **才用** task-executor + code-reviewer
- Stage 3 (/write-document) 用 writer + verifier + code-reviewer

### 6.4 Files × Stages

| Path pattern | 寫入者 | Stage | Commit by |
|---|---|---|---|
| `.specify/memory/` | bootstrap.sh (mkdir) | S0 | n/a |
| `.specify/specs/` | bootstrap.sh + brainstorming + bugfix + write-document | S0/S1/S2/S3 | varies |
| `.specify/bugs/` | bootstrap.sh + bugfix | S0/S2 | bugfix skill |
| `.claude/{logs,agent-memory,state}/` | bootstrap.sh | S0 | gitignored |
| `CLAUDE.md` | /setup wizard or `/init` | S0.5 | manual |
| **`.specify/specs/YYYY-MM-DD-<topic>-design.md`** | brainstorming | **S1** | brainstorming "commit design document" (no enforced prefix) |
| **`.specify/plans/YYYY-MM-DD-<feature>.md`** | writing-plans | **S1** | writing-plans (no enforced prefix) |
| (worktree code/test) | implementer subagent | S1 each task | implementer self-commit |
| `.specify/bugs/{bug-id}/report.md` | bugfix Phase 1 | S2 | `docs: {bug-id} — report` |
| `.specify/bugs/{bug-id}/analysis.md` | bugfix Phase 2 | S2 | `docs: {bug-id} — root cause analysis` |
| (worktree code/test in feat/bugfix-{id}/fix) | task-executor (Phase 3a) | S2 | `test(scope): [BUG-{id}]` + `fix(scope): [BUG-{id}]` |
| `.specify/bugs/{bug-id}/verification.md` | bugfix Phase 4 | S2 | `docs: {bug-id} — verification report` |
| `.specify/specs/{name}/spec.md` | write-document Phase 1 | S3 | `spec: doc-{name} — requirements` |
| `.specify/specs/{name}/plan.md` | write-document Phase 2 | S3 | `plan: doc-{name} — structure and terminology` |
| `.specify/specs/{name}/tasks.md` | write-document Phase 3 | S3 | `tasks: doc-{name} — task decomposition` |
| `.specify/specs/{name}/drafts/T00X-{slug}.md` | writer agent (Phase 4a) | S3 | `draft(doc): [T00X]` |
| `.specify/specs/{name}/final-review.md` | write-document Phase 5 | S3 | `docs: doc-{name} — final review` |
| `.claude/state/phase.json` | scripts/scope set | S6 | gitignored, never commit |
| `.claude/logs/agent-activity.jsonl` | subagent-{start,stop} hooks | S1/S2/S3 | gitignored |
| `.claude/logs/notifications.log` | notify hook | varies | gitignored |

**注意**：vendored skills 使用 `YYYY-MM-DD-<topic>` 命名，custom skills 使用 `{name}/` 子目錄。兩種風格共存於 `.specify/`。

---

## Section 7: Troubleshooting 索引

撞到 enforcement 時的 quick reference。完整情境描述見 Stage 7。

| 現象關鍵字 | 來源 | Stage 對照 | 修法 |
|---|---|---|---|
| `Cannot edit on "main"` | branch-enforce | 7.1 | `git switch -c feat/your-feature` |
| `not allowed for edits` | branch-enforce | 7.2 | rename branch 或開新 feat/* |
| `missing subtask marker` | worktree-enforce | 7.3 | 用 canonical naming（feat/foo/T001 / feat/bugfix-001/fix / feature/foo） |
| `Bad commit message, expected pattern` | conventional-pre-commit | 7.4 | 用合法 type prefix |
| `gitleaks: WARN secret detected` | gitleaks | 7.5 | 移除 secret + revert + re-commit |
| `permission denied: Bash(git push --force*)` | permissions.deny | 7.6 | 別 force push |
| `permission denied: Bash(rm -rf *)` | permissions.deny | 7.7 | 用精準 path |
| `outside current task scope` | scope-enforce | 7.8 | scope set/clear |
| `jq required by hooks` | bootstrap.sh | 7.9 | brew/apt/scoop install jq |
| `HARD-GATE` 等待 design approve | brainstorming skill | 7.10 | review design + approve（或顯式 skip） |

---

## Section 8: Maintenance Notes

### 8.1 兩層架構

本 template 是 vendored + custom 雙層：

```
.claude/
├── skills/
│   ├── (14 vendored from obra/superpowers, MIT)
│   │   ├── brainstorming/                  ← 不動
│   │   ├── writing-plans/                  ← 不動
│   │   ├── subagent-driven-development/    ← 不動
│   │   └── ... (11 more)
│   ├── karpathy-guidelines/                ← vendored from forrestchang, MIT, 不動
│   ├── setup/                              ← custom
│   ├── bugfix/                             ← custom
│   └── write-document/                     ← custom
├── agents/
│   ├── code-reviewer.md                    ← vendored from Superpowers, 不動
│   ├── task-executor.md                    ← custom
│   ├── writer.md                           ← custom
│   └── verifier.md                         ← custom
├── hooks/                                  ← 全部 custom
├── scripts/                                ← 全部 custom
└── settings.json                           ← custom
```

### 8.2 已知設計差異（兩層之間）

| 維度 | Vendored Superpowers | Custom |
|---|---|---|
| Spec 路徑 | `.specify/specs/YYYY-MM-DD-<topic>-design.md` | `.specify/specs/{name}/spec.md` 或 `.specify/bugs/{id}/report.md` |
| Plan 路徑 | `.specify/plans/YYYY-MM-DD-<feature>.md` | `.specify/specs/{name}/plan.md` |
| Branch 命名 | `feature/<name>` | `feat/{name}/T00X` 或 `feat/bugfix-{id}/fix` |
| Commit prefix | 不強制（部分範例用 `feat:`） | 強制（`spec:` `plan:` `tasks:` `draft(doc):` `verify(doc):` `docs:` `test:` `fix:`） |
| Subagent dispatch | 自帶 prompt-template subagents（implementer/spec-reviewer/code-quality-reviewer） | named agents（task-executor/code-reviewer/writer/verifier） |
| Agent 持久性 | 全 ephemeral | task-executor/code-reviewer ephemeral；writer/verifier persistent |
| Test/review 強度 | TDD Iron Law + two-stage review | TDD Iron Law（bugfix only）+ two-stage review |

### 8.3 Sync upstream Superpowers

```bash
cd /tmp && rm -rf superpowers
git clone --depth=1 https://github.com/obra/superpowers
cp -r /tmp/superpowers/skills/. <this-repo>/.claude/skills/
cp /tmp/superpowers/agents/code-reviewer.md <this-repo>/.claude/agents/
cp /tmp/superpowers/LICENSE <this-repo>/.claude/SUPERPOWERS_LICENSE
# 重跑 sed 置換 docs/superpowers/ → .specify/ 和 superpowers: → ""
```

完整指令見 `.claude/ATTRIBUTION.md`。

### 8.4 改 hook / skill 的責任歸屬

| 檔案 | 改動原則 |
|---|---|
| `.claude/skills/{brainstorming,writing-plans,...}/` (vendored) | **不動**。改了會破壞 sync upstream |
| `.claude/skills/karpathy-guidelines/` (vendored) | **不動** |
| `.claude/agents/code-reviewer.md` (vendored) | **不動** |
| `.claude/skills/{setup,bugfix,write-document}/` | 自由改，注意對外 commit prefix 別亂改 |
| `.claude/agents/{task-executor,writer,verifier}.md` | 自由改 |
| `.claude/hooks/*.sh` | 自由改 |
| `.claude/scripts/scope` | 自由改 |
| `.claude/settings.json` | 自由改，但更動 hook event 註冊要小心 |
| `.pre-commit-config.yaml` | 自由改（升 rev 注意相容性）|

### 8.5 加新 skill

1. 建立 `.claude/skills/<n>/SKILL.md`，含 frontmatter（`name`、`description`、optional `disable-model-invocation`）
2. 若需 auto-invoke：寫好 `description` 描述觸發條件
3. 若需 skill-router 強化：加 keyword 到 `.claude/skill-rules.json`
4. 若是 orchestrator skill：考慮設 `disable-model-invocation: true` 強制只能手動觸發

### 8.6 加新 agent

1. 建立 `.claude/agents/<n>.md`，含 frontmatter（`name`、`description`、`model`、optional `tools`、`isolation`、`memory`）
2. 在某個 custom skill 內顯式 dispatch
3. 不需要在 settings.json 註冊（agent 由 skill 透過 Task tool dispatch）

### 8.7 加新 hook

1. 建立 `.claude/hooks/<n>.sh`，開頭加 `command -v jq >/dev/null 2>&1 || exit 0`
2. 在 `.claude/settings.json` `hooks.<EventName>` 陣列加 entry
3. 確保 chmod +x（git ls-files --stage 應為 100755）
4. 跑單元測試（用 `echo '{"...":"..."}' | bash .claude/hooks/<n>.sh` 驗證）

---

## 附錄 A: Hook 觸發時序圖

```
你打字
  │
  ▼
┌─────────────────────────────────────────────────────────┐
│ UserPromptSubmit hook                                    │
│   → skill-router.sh                                      │
│     - jq 缺失 → exit 0                                  │
│     - rules file 缺失 → exit 0                          │
│     - 短於 10 字 → exit 0                                │
│     - 命中 negative keyword → exit 0                    │
│     - 命中正向 rule → output additionalContext hint     │
└─────────────────────────────────────────────────────────┘
  │
  ▼
Main Claude 處理 prompt（可能呼叫 skill）
  │
  ├─ Tool calls (Edit/Write) ───────────────────────────┐
  │                                                     │
  │   ┌────────────────────────────────────────────┐   │
  │   │ PreToolUse hooks (Edit|Write):              │   │
  │   │   1. branch-enforce.sh                      │   │
  │   │      - main/master → deny                   │   │
  │   │      - feat/chore/docs/bugfix/* → allow     │   │
  │   │      - 其他 → deny                          │   │
  │   │   2. scope-enforce.sh                       │   │
  │   │      - state file 缺失 → allow              │   │
  │   │      - in scope → allow                     │   │
  │   │      - out of scope → deny                  │   │
  │   │ 任一 deny → 整個 tool call 被擋             │   │
  │   └────────────────────────────────────────────┘   │
  │                  │                                  │
  │                  ▼                                  │
  │            (執行 tool)                              │
  │                  │                                  │
  │   ┌────────────────────────────────────────────┐   │
  │   │ PostToolUse hooks (Edit):                   │   │
  │   │   - auto-format.sh (per-language, opt-in)  │   │
  │   │ 不能 deny，只能執行                          │   │
  │   └────────────────────────────────────────────┘   │
  │                                                     │
  │   permissions.deny 同時擋 Bash 違規                  │
  │                                                     │
  ├─ Subagent dispatch (Task tool) ─────────────────────┤
  │                                                     │
  │   ┌────────────────────────────────────────────┐   │
  │   │ SubagentStart hook                          │   │
  │   │   → log to .claude/logs/agent-activity.jsonl│   │
  │   └────────────────────────────────────────────┘   │
  │                  │                                  │
  │   ┌──────────────┴────────────────────────────┐    │
  │   │ Subagent execution                         │    │
  │   │ (受 isolation: worktree 影響)              │    │
  │   │ 內部仍會觸發 PreToolUse hooks              │    │
  │   └──────────────┬────────────────────────────┘    │
  │                  │                                  │
  │   ┌────────────────────────────────────────────┐   │
  │   │ SubagentStop hook                           │   │
  │   │   → log + 桌面通知 (osascript)              │   │
  │   └────────────────────────────────────────────┘   │
  │                                                     │
  ├─ Worktree create (git worktree add) ────────────────┤
  │                                                     │
  │   ┌────────────────────────────────────────────┐   │
  │   │ WorktreeCreate hook                         │   │
  │   │   → worktree-enforce.sh                     │   │
  │   │     - feat/{name}/T00X → allow              │   │
  │   │     - feat/bugfix-*/fix → allow             │   │
  │   │     - feat/bugfix-*/T00X → allow            │   │
  │   │     - feature/* → allow                     │   │
  │   │     - feat/* (no sub-pattern) → block       │   │
  │   │     - 其他 → allow (不 enforce)             │   │
  │   └────────────────────────────────────────────┘   │
  │                                                     │
  ▼
回覆完成
  │
  ▼
┌─────────────────────────────────────────────────────────┐
│ Stop hook                                                │
│   → stop-verify.sh                                       │
│     - 偵測 git diff                                      │
│     - 無變更 → exit 0                                    │
│     - 有變更 → 跑 lint/typecheck（預設全註解）            │
│     - opt-in blocking 段落（預設關閉）                    │
└─────────────────────────────────────────────────────────┘

外加：
- Notification hook：Claude 需要使用者注意時觸發 → 桌面通知 + log
- pre-commit hook (git native, 由 pre-commit framework 安裝)：
    git commit 時驗證 conventional commit 格式 + 跑 gitleaks secret 掃描
```

---

## 附錄 B: 不會被擋下的小事

下面這些 prompt **不會** 觸發 skill-router 強制路由：

- 短於 10 字的 prompt
- 含 negative keyword 的 prompt（typo / comment / rename / format / quick / 小改 / 小修 / 改個字 / 拼字 / 註解 / 重命名）
- 純 Q&A（解釋程式碼、查 doc、看歷史）

但這些**仍會觸發** branch-enforce：

- 任何 Edit/Write tool call，無論 prompt 內容

換言之：**skill 路由是建議性的，branch 規則是強制的**。

---

## 附錄 C: 使用心法

1. **不要記指令 — 直接描述意圖**。skill-router 會幫你導到對的 skill。
2. **HARD-GATE 不是擋路 — 是保護你**。brainstorming 不准未經 approve 寫 code，是因為 LLM 經常假設錯方向。
3. **撞到 hook 擋下不是 bug — 是 feature**。訊息會告訴你怎麼修。
4. **Subagent 用完即棄 — 不要期待跨 task 記憶**。code 風格 / 設計決定要寫進 plan 或 CLAUDE.md。
5. **scope enforcement 是 opt-in — 預設不擾**。只在你明確擔心 AI 越界時開。
6. **小改不需 4-phase**。改 typo 就改 typo，AI 不會強迫你跑 brainstorming。
7. **Code 新功能用 Superpowers chain；bug 用 /bugfix；文件用 /write-document**。三條入口走三條截然不同的 flow。
8. **Vendored 不要動，custom 隨便改**。改 vendored 會破壞 sync upstream。





