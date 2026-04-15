# Third-Party Attributions

本 template 整合了以下開源 skill/agent 資源。所有來源皆為 MIT license，相容於本專案使用。

---

## obra/superpowers

- **Source**: https://github.com/obra/superpowers
- **License**: MIT（完整條款見 `.claude/SUPERPOWERS_LICENSE`）
- **Copyright**: © 2025 Jesse Vincent
- **整合方式**: Vendor（複製 upstream 內容至本 repo，非 plugin 依賴）

### Vendored Skills（14 個）

| Skill | 用途 |
|---|---|
| `brainstorming` | Spec 階段對話，HARD-GATE design approval |
| `writing-plans` | 實作 plan 撰寫 |
| `executing-plans` | 單一 session 執行 plan |
| `subagent-driven-development` | Fresh subagent per task + two-stage review |
| `test-driven-development` | TDD Iron Law：no production code without failing test |
| `systematic-debugging` | Root-cause 導向的 debug 流程 |
| `requesting-code-review` | 請求 review 的結構 |
| `receiving-code-review` | 收到 review 的處理流程 |
| `verification-before-completion` | Task 完成前 self-check gate |
| `dispatching-parallel-agents` | Wave 平行 dispatch |
| `using-git-worktrees` | Worktree 隔離慣例 |
| `finishing-a-development-branch` | Branch 收尾與 PR 開立 |
| `using-superpowers` | Superpowers meta 入口 |
| `writing-skills` | Meta-skill：用 TDD 方式撰寫新 skill |

### Vendored Agent

- `code-reviewer.md`（two-stage review protocol：spec compliance → code quality）

### 本地修改（upstream 未變，只改以下三項以對齊本 template 慣例）

1. **路徑對齊**: 所有 `docs/superpowers/specs/` → `.specify/specs/`，`docs/superpowers/plans/` → `.specify/plans/`
2. **Cross-reference prefix 移除**: `superpowers:skill-name` → `skill-name`（無 plugin namespace 時 local 解析即可）
3. **不包含** upstream 的 `hooks/session-start`、`commands/*`、`package.json`、`gemini-extension.json`、`AGENTS.md`、`GEMINI.md`（與本 template 架構無關或重複）

### 未來 sync upstream 的做法

```bash
cd /tmp && rm -rf superpowers && git clone --depth=1 https://github.com/obra/superpowers
cp -r /tmp/superpowers/skills/. <this-repo>/.claude/skills/
cp /tmp/superpowers/agents/code-reviewer.md <this-repo>/.claude/agents/
cp /tmp/superpowers/LICENSE <this-repo>/.claude/SUPERPOWERS_LICENSE
# 重跑 sed 置換（見 docs/design/ 計劃 Step 4）
```

---

## t0ddharris/claude-code-skills

- **Source**: https://github.com/t0ddharris/claude-code-skills
- **License**: MIT（完整條款見 `.claude/T0DDHARRIS_LICENSE`）
- **Copyright**: © 2026 Todd Harris
- **整合方式**: Vendor（複製 upstream 內容至本 repo）

### Vendored Skills（3 個：session handover）

| Skill | 用途 |
|---|---|
| `brief` | 寫 session-brief.md 並 commit+push 到 git（session 結束 checkpoint）|
| `start` | 讀 session-brief.md + git status，給下一 session 摘要 |
| `reflect` | 掃對話中的修正 / approval / pattern，提議 skill 更新（continuous learning）|

### 使用流程

```
session 進行中
  ↓（準備 /clear 或 session 要結束）
/brief  →  寫 /brief/session-brief.md + commit + push
  ↓ /clear 或新 session
/start  →  讀 /brief/session-brief.md + git log，回報進度
  ↓ 繼續工作
(可選) /reflect  →  掃對話找 correction，提議 skill 改動
```

### 輸出檔案路徑

- `/brief/session-brief.md` — project root 下的 `brief/` 目錄。非 gitignored（是 commit 的一部分）。**不會動到 `.specify/` 或 `.claude/`**。

### 本地修改

無。原封複製 3 個 SKILL.md。

---

## forrestchang/andrej-karpathy-skills

- **Source**: https://github.com/forrestchang/andrej-karpathy-skills
- **License**: MIT（宣告於 SKILL.md frontmatter `license: MIT`）
- **Copyright**: © forrestchang
- **整合方式**: Vendor（單一 skill 複製）

### Vendored Skill

- `karpathy-guidelines` — Karpathy 行為準則：減少 LLM 常見 coding 錯誤（過度預設、擴大 scope、過早抽象）

### 本地修改

無，原封複製。

---

## 本 template 原創內容（無外部來源）

以下由本 template 自行撰寫，不是 vendored：

- `.claude/skills/setup/SKILL.md` — 互動式首次設定 wizard
- `.claude/skills/bugfix/SKILL.md` — Bug 修復 4-phase 流程（Report → Analyze → Fix → Verify）
- `.claude/skills/write-document/SKILL.md` — 文件專案 4-phase 流程
- `.claude/agents/task-executor.md` — Ephemeral subagent profile for code tasks
- `.claude/agents/writer.md` — 文件專案撰寫 agent
- `.claude/agents/verifier.md` — 文件專案查核 agent
- `.claude/hooks/*.sh` — 5 個 hook scripts（auto-format、notify、stop-verify、subagent-start-log、subagent-stop-gate）
- `.claude/settings.json` — 6 hook events 配置 + permissions.deny
- `CLAUDE.md.example`、`README.md`、`SETUP_GUIDE.md`、`scheduled-tasks.md`、`bootstrap.sh`
