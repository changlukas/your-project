# Setup Guide

## 自動設定（推薦）

```bash
claude
> /setup
```

/setup 會依序引導你完成以下所有步驟。

---

## 手動設定

### Step 1: 生成 CLAUDE.md

```bash
claude
> /init
```

Claude 會分析 codebase 自動生成。生成後精煉：
- 確認技術棧、build/test/lint 指令正確
- 刪掉 Claude 能自己學會的東西
- 控制在 80 行以內

空專案用 CLAUDE.md.example 作參考手動建立。

### Step 2: 設定 Formatter Hook（Code 專案）

編輯 `.claude/hooks/auto-format.sh`，取消註解你的語言：

| 語言 | Formatter | 取消註解 |
|------|-----------|---------|
| JavaScript / TypeScript | Prettier | `npx prettier --write "$FILE"` |
| Python | Ruff | `ruff format "$FILE"` |
| Go | gofmt | `gofmt -w "$FILE"` |
| Rust | rustfmt | `rustfmt "$FILE"` |
| C / C++ | clang-format | `clang-format -i "$FILE"` |
| SystemVerilog | Verible | `verible-verilog-format --inplace "$FILE"` |

文件專案通常不需要 formatter hook。

確認執行權限：`chmod +x .claude/hooks/auto-format.sh`

> **注意：** Template 初始化時 hook scripts 內所有語言區塊預設都保持註解狀態。
> 請在此步驟依你的專案語言手動取消註解。

### Step 3: 調整 Agent 工具權限

Code 專案：`.claude/agents/task-executor.md` 的 `tools` 欄位可能需要加入
你的 build/test 指令（如 `Bash(npm:*)`、`Bash(pytest:*)`）。

文件專案：`.claude/agents/writer.md` 的 `tools` 欄位可能需要加入
LaTeX、pandoc 等工具。

其他 agents（`code-reviewer.md`、`verifier.md`）通常不用改。

### Step 4: Skills（可選）

只在你發現自己重複給 Claude 同樣指令時才建。

#### 跨專案共用 Skills（--add-dir）

如果你有跨專案共用的 skills（coding standards、文件格式、claim 結構等），
建議放在獨立目錄，用 `--add-dir` 載入：

```bash
claude --add-dir ~/shared-skills
```

或在 `~/.claude/settings.json` 永久配置：

```json
{
  "additionalDirectories": ["~/shared-skills"]
}
```

共用目錄結構：

```
~/shared-skills/
└── .claude/
    └── skills/
        ├── rtl-coding/
        ├── slide-gen/
        └── patent-drafting/
```

`.claude/skills/` 在 --add-dir 目錄裡會被自動發現和載入，支援 live change detection —
改了 SKILL.md 當前 session 立刻生效，不需重啟 Claude Code。

### Step 5: MCP（可選）

編輯 `.mcp.json` 加入外部工具（GitHub, DB, Playwright 等）。

### Step 6: Spec Kit（可選）

```bash
uv tool install specify-cli \
  --from git+https://github.com/github/spec-kit.git
specify init . --ai claude --ai-skills
```

本 template 的目錄結構已對齊 spec-kit 官方慣例（`.specify/memory/`、`.specify/specs/`），
可與 specify-cli 無縫共存。

### Step 7: 推薦 Claude Code Plugins（可選）

下列第三方 plugins 可進一步補強 enforcement，搭配本 template 的 hooks：

```bash
# TDD Iron Law 強制（多語言 test runner 整合）
/plugin install tdd-guard

# Plan review 視覺 UI（在 ExitPlanMode 觸發瀏覽器標註）
/plugin marketplace add backnotprop/plannotator
/plugin install plannotator
```

完整資訊：
- [nizos/tdd-guard](https://github.com/nizos/tdd-guard) (MIT)
- [backnotprop/plannotator](https://github.com/backnotprop/plannotator) (MIT/Apache-2.0)

### Step 8: pre-commit framework（強烈建議）

```bash
pipx install pre-commit  # 或: pip install --user pre-commit
pre-commit install
```

啟用後，commit 時自動跑：
- `conventional-pre-commit` — commit message 格式驗證
- `gitleaks` — 已知 secret 模式掃描

`bootstrap.sh` 會嘗試自動安裝，失敗時手動跑上面兩行即可。

---

## settings.json 說明

預設配置包含：

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: 啟用 Agent Teams
- `permissions.deny`: 擋掉 rm -rf、git push --force、push/rebase main、reset --hard、clean -fdx 等
- `hooks.UserPromptSubmit`: 自動 skill 路由（讀 `.claude/skill-rules.json`）
- `hooks.PreToolUse`: branch enforcement（feat/chore/docs/bugfix only）+ scope enforcement（opt-in）
- `hooks.PostToolUse`: 每次編輯後自動跑 formatter（按語言 opt-in）
- `hooks.Stop`: 每次回覆結束跑 lint/type-check
- `hooks.SubagentStart/Stop`: 記錄 subagent 生命週期 + 桌面通知
- `hooks.Notification`: agent 需要輸入或完成時桌面通知
- `hooks.WorktreeCreate`: 強制 worktree branch 命名符合 canonical pattern

這些通常不需要改。

---

## 檔案速查

| 檔案 | 需要改嗎 |
|------|---------|
| CLAUDE.md | ✅ 必改（/init 或 /setup 生成） |
| .claude/hooks/auto-format.sh | ✅ 取消註解對應語言（Code 專案） |
| .claude/hooks/stop-verify.sh | ✅ 取消註解對應語言（Code 專案） |
| .claude/agents/task-executor.md | ⚠️ 可能改 tools（Code 專案，加入 build/test 指令） |
| .claude/agents/writer.md | ⚠️ 可能改 tools（文件專案，LaTeX/pandoc 等） |
| .claude/settings.json | ❌ 通用 |
| .claude/agents/code-reviewer.md | ❌ 通用（vendor 自 Superpowers） |
| .claude/agents/verifier.md | ❌ 通用 |
| .claude/skills/setup/SKILL.md | ❌ 通用 |
| .claude/skills/bugfix/SKILL.md | ❌ 通用 |
| .claude/skills/write-document/SKILL.md | ❌ 通用 |
| .claude/skills/{brainstorming,writing-plans,...}/ | ❌ vendor 自 Superpowers，勿動 |
| .claude/skills/karpathy-guidelines/ | ❌ vendor 自 andrej-karpathy-skills |
| .claude/ATTRIBUTION.md | ❌ 授權資訊 |
| .claude/SUPERPOWERS_LICENSE | ❌ MIT license 全文 |
| .mcp.json | ⚠️ 按需添加 |

## 第三方 Skill Attribution

本 template vendor 了兩個外部開源 skill 來源：

- **obra/superpowers**（MIT）— 14 個 code-oriented skills + code-reviewer agent
- **forrestchang/andrej-karpathy-skills**（MIT）— karpathy-guidelines skill

完整授權資訊、vendored 清單、本地修改項目見 [.claude/ATTRIBUTION.md](.claude/ATTRIBUTION.md)。

## 心智模型

本 template 的 Code 專案 flow 採用 **ephemeral subagent + skills** 模型：
task 執行者是用完即棄的 subagent，不是 persistent named role。
文件專案則保留 persistent writer/verifier 以維持跨章節語氣與術語一致。

詳細論證見 `docs/design/AGENT_MODEL.md`（parent dir，不隨 template 傳給新專案）。
