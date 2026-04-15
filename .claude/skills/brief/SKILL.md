---
name: brief
version: 2.0.0
description: "/brief - Write session brief, commit, and push. Run at end of session to checkpoint all work."
---

# Session Brief

Run this at the end of a session to capture context and checkpoint all work to GitHub.

## Steps

### 1. Review Existing Brief

Read `/brief/session-brief.md` to understand what was there from last session.

### 2. Write the New Brief

Overwrite `/brief/session-brief.md` with a comprehensive brief covering:

- **Date, time (EST), and session number** at the top
- Important progress made in the current session
- Key decisions and architectural changes
- Unfinished tasks and next steps
- Technical details that need to be preserved
- Any context that would be lost between sessions

This is NOT about brevity — be as thorough as needed to retain all important context.

### 2.5. Reflect on Skills (Optional)

If the `reflect` skill is installed, run it after writing the brief to scan the conversation for learnings. This is a delegation, not a repeat of the reflect instructions — load and follow the reflect skill.

- If learnings are found: present them to the user alongside the brief, before committing
- If no learnings: report "no new skill learnings detected" in one line and continue
- Any approved skill updates will be committed together with the brief in Step 3

If the reflect skill is not installed, skip this step.

### 3. Commit and Push

After writing the brief:

1. Run `git status` to see all changes (staged + unstaged + untracked)
2. Run `git log --oneline -3` to match commit message style
3. Stage all relevant files (`git add` — use specific paths, not `-A`)
4. Commit with message format: `Session [N]: [1-2 sentence summary of session work]`
5. Push to origin: `git push`

**Commit rules:**
- Do NOT stage files that look like secrets (`.env`, credentials, tokens)
- If there are uncommitted changes unrelated to this session, ask the user before including them
- If push fails (e.g., remote is ahead), stop and ask the user — do not force push

## When to Use

- At the end of significant sessions
- When important decisions have been made
- Before ending a session where critical details might be lost
- When the user explicitly requests `/brief`

## Read-Only Mode

When asked to "read the brief" (typically at session start via `/start`), just read the file without modifying it. Do not commit or push in read-only mode.
