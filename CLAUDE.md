# Hot/Cold Data Patent Analysis

專利概念報告的分析、評估與修訂專案。核心主題：資料溫度感知與記憶體層級放置控制。

## Tech Stack
- Language: Markdown (document project, no code)
- Build: N/A
- Test: N/A (document verification via review workflow)

## Architecture
- `docs/patent/hardware_hot_cold_sensing_patent_report.md`: 原始專利概念報告（含 Wave 1 修訂）
- `docs/patent/research-notes.md`: 前案研究 + 專利寫作風格研究
- `docs/patent/review.md`: 主管回饋 + AI 討論記錄
- `.specify/specs/`: Spec / Plan / Tasks per revision phase
- `docs/reviews/`: Review reports and workflow findings
- `.claude/skills/`: Workflow skills (write-document, review-document)

## Critical Rules
- ALWAYS research before deciding: before implementing, designing, or fixing anything,
  search for official documentation, open source references, and industry standards first.
  Do NOT rely on training knowledge alone — verify against current sources.
  This applies to: architecture decisions, library choices, bug fixes, API usage,
  protocol implementations, and any technical judgment call.
- ALWAYS follow your-project workflow skills (write-document, review-document) when applicable
- ALWAYS use the terminology defined in `.specify/specs/*/plan.md` — banned terms must not appear in output
- NEVER imagine how patents are written — research real patent examples first

## Context References
- Patent pivot decision: see `docs/reviews/patent-report-review-2026-04-16.md`
- Terminology table: see `.specify/specs/patent-revision-phase1/plan.md`
- Interface contracts: see `.specify/specs/patent-revision-phase1/tasks.md`
- Research findings: see `docs/patent/research-notes.md`
