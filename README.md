# claude-project-memory

Lightweight persistent memory for Claude Code projects. One script gives Claude context, corrections, and architectural decisions that survive across sessions.

## The Problem

Claude Code starts every session from scratch. It reads your code but doesn't remember:
- Mistakes it made last time (and your corrections)
- Architectural decisions and *why* they were made
- What's currently working, in progress, or broken

This template fixes that with 3 markdown files, 1 hook, and clear instructions in CLAUDE.md.

## Quick Start

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/eugeniogotti-prog/claude-project-memory/main/init.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/eugeniogotti-prog/claude-project-memory.git /tmp/cpm
bash /tmp/cpm/init.sh
```

Then open `CLAUDE.md` and fill in your project's stack, architecture, and conventions.

## What It Creates

```
your-project/
├── CLAUDE.md                      # Project instructions (auto-loaded by Claude Code)
├── .claude/
│   ├── settings.json              # Hook configuration
│   └── hooks/
│       └── session-orient.sh      # Injects memory at session start
└── .claude-memory/                # Persistent memory (gitignored)
    ├── corrections.md             # User corrections → don't repeat mistakes
    ├── decisions.md               # Architectural decisions → don't re-debate
    └── status.md                  # Current state → know where we are
```

## How It Works

### At session start
The `session-orient.sh` hook fires automatically and injects into Claude's context:
- Current project status from `status.md`
- Active corrections from `corrections.md`
- Architectural decisions from `decisions.md`
- Last 5 git commits + branch + dirty files

### During the session
CLAUDE.md instructs Claude to:
- Check `corrections.md` before repeating a pattern the user previously corrected
- Reference `decisions.md` before proposing alternatives to settled decisions
- Log new corrections and decisions as they happen

### At session end
Claude updates `status.md` with what was done and what's pending.

## The Three Memory Files

### corrections.md
Tracks mistakes Claude made and how the user corrected them. Claude reads this before acting to avoid repeating errors.

```markdown
| Date | What | Error | Correction |
|------|------|-------|------------|
| 2026-04-01 | DB tests | Mocked the database | Use real DB — mocks masked a broken migration |
| 2026-04-02 | API route | Used default export | Named exports only in this project |
```

### decisions.md
Captures architectural decisions with their rationale. Prevents Claude from re-proposing alternatives that were already considered and rejected.

```markdown
| Date | Decision | Why | Rejected alternatives |
|------|----------|-----|----------------------|
| 2026-03-15 | PostgreSQL over SQLite | Need concurrent writes + vector search | SQLite (no pgvector), MongoDB (team expertise) |
| 2026-03-20 | Gemini for embeddings | Cost + 768D vectors fit pgvector | OpenAI (expensive), local models (slow) |
```

### status.md
Living document of project state. Updated at end of each session.

```markdown
## Working
- Auth flow (login, register, JWT)
- Chat streaming (SSE)

## In Progress
- File upload endpoint

## To Do
- Payment integration
- Admin dashboard
```

## CLAUDE.md Template

The generated `CLAUDE.md` includes:
- Project description placeholder
- Stack section
- Architecture section
- Conventions section
- Useful commands section
- **Memory orchestration rules** — explicit instructions for Claude to read, update, and maintain the memory files

## Comparison with Other Approaches

| | claude-project-memory | OpenWolf | Raw CLAUDE.md |
|---|---|---|---|
| **Memory** | 3 focused files | anatomy + cerebrum + memory + buglog | None |
| **Hooks** | 1 (session start) | 6 (pre/post read/write + start/stop) | None |
| **Complexity** | Minimal (1 script, 3 md files) | Heavy (Node.js daemon, file tracking) | None |
| **Token overhead** | ~20 lines injected | Varies (can be significant) | None |
| **Setup** | 1 command | npm install + init | Manual |
| **Scope** | Decisions, corrections, status | File reads, token tracking, bug fixes | — |

## Philosophy

- **Lightweight over comprehensive.** 3 files that matter > 10 files that get ignored.
- **Markdown over JSON.** Human-readable, easy to edit, works in any editor.
- **Convention over enforcement.** CLAUDE.md tells Claude what to do; it's not a hard technical constraint.
- **Gitignored by default.** Memory is personal to the developer, not shared in the repo.

## Requirements

- Claude Code CLI
- Bash
- Git (optional, for git status in hook)

## License

MIT
