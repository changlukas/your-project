# Scheduled Tasks (Routines)

自動化的定期維護任務。獨立於 orchestrator 流程之外，不需要人類觸發。

Claude Code 的排程機制稱為 **Routines**，跑在雲端環境，即使你的本機關機也會執行。
管理介面：[claude.ai/code/routines](https://claude.ai/code/routines)

## 啟用方式

在 Claude Code session 裡用 slash command 建立：

```
/schedule daily code quality scan
```

Claude 會引導你完成：
1. 任務描述（Claude 要做什麼）
2. Cron schedule（何時執行）
3. Environment / connectors（tool 權限、MCP 整合、環境變數）

也可以直接到 [claude.ai/code/routines](https://claude.ai/code/routines) 網頁介面建立和管理。

## 推薦的排程任務

### 每日：Code Quality 掃描
```
/schedule Daily code quality scan
  Description: Scan codebase for dead code, unused imports, and TODO comments.
               Write findings to .claude/logs/daily-quality.md
  Cron: 0 9 * * *
```

### 每週：Dependency Audit
```
/schedule Weekly dependency audit
  Description: Check for outdated or vulnerable dependencies.
               Write report to .claude/logs/weekly-deps.md
  Cron: 0 10 * * 1
```

### 每週：文件同步檢查
```
/schedule Weekly docs sync check
  Description: Compare README and docs/ against current codebase.
               Flag anything outdated or missing.
               Write report to .claude/logs/weekly-docs.md
  Cron: 0 14 * * 5
```

### 每月：Architecture Drift 檢測
```
/schedule Monthly architecture drift
  Description: Compare current codebase structure against .specify/ specs.
               Identify architectural drift or undocumented changes.
               Write report to .claude/logs/monthly-drift.md
  Cron: 0 10 1 * *
```

## 管理

所有管理透過 `/schedule` slash command 或 [claude.ai/code/routines](https://claude.ai/code/routines) 網頁介面：
- 查看所有 routines
- 編輯 / 暫停 / 恢復 / 刪除
- 檢視執行歷史與輸出

## 注意事項

- **訂閱配額**：Routines 在雲端環境執行，消耗你的 Claude Code 使用額度
- **Tool 權限**：由 connector / MCP 整合控制，不是透過 CLI flag。建議只開讀取 + 寫報告的連接器，不要讓 routine 自動改 code
- **報告輸出**：routines 若要寫檔到你的專案，需要適當的 git / filesystem connector；寫到 `.claude/logs/` 後人工 review 再決定是否行動
- **`/loop` 是不同機制**：`/loop` 是 in-session recurring（同一個 Claude session 內重複跑），適合「檢查 build 狀態」這類短暫場景，不是 Routines 的替代

## 參考

- 官方文件：[code.claude.com/docs/en/routines](https://code.claude.com/docs/en/routines.md)
