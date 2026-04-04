# claude-project-memory

Lightweight persistent memory for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). One script, three markdown files, one hook — Claude remembers your corrections, respects your decisions, and knows where the project stands. Across every session.

## Why?

Claude Code is powerful, but every session starts from zero. It reads your code, but it doesn't know:

- That you corrected it three times last week for using `var` instead of `const`
- That you chose PostgreSQL over SQLite two months ago, and why
- That the auth system works fine but the payment integration is half-done
- That the last session ended with a failing test you haven't fixed yet

Without memory, Claude re-discovers these things by reading files, asking questions, or — worse — making the same mistakes again.

**claude-project-memory** gives Claude a small, focused memory that answers three questions at the start of every session:

1. **What did I get wrong before?** → `corrections.md`
2. **What has already been decided?** → `decisions.md`
3. **Where are we right now?** → `status.md`

## Quick Start

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/eugeniogotti-prog/claude-project-memory/main/init.sh | bash
```

Then open `CLAUDE.md` and fill in your project details (stack, architecture, conventions).

That's it. Next time you run `claude` in that directory, the memory is active.

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

- **CLAUDE.md** is committed to the repo — it's project documentation that anyone benefits from.
- **.claude-memory/** is gitignored — it's personal to your development workflow.
- **.claude/hooks/** is committed — the hook is part of the project setup.

## How It Works

```
┌──────────────────────────────────────────────────────────┐
│                    SESSION START                          │
│                                                          │
│  1. Claude Code loads CLAUDE.md (automatic)              │
│  2. Hook fires → reads .claude-memory/*                  │
│  3. Claude receives: status + corrections + decisions    │
│     + last 5 git commits + branch + dirty files          │
│                                                          │
│  Claude now knows:                                       │
│  - What works, what's broken, what's next                │
│  - What mistakes to avoid                                │
│  - What decisions are settled                             │
│  - What changed since last session (git)                 │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│                    DURING SESSION                         │
│                                                          │
│  • User corrects Claude → Claude adds to corrections.md  │
│  • Architectural decision made → Claude adds to          │
│    decisions.md                                          │
│  • Claude checks corrections.md before repeating a       │
│    pattern that was previously corrected                  │
│  • Claude checks decisions.md before proposing           │
│    alternatives to settled decisions                      │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│                    SESSION END                            │
│                                                          │
│  Claude updates status.md:                               │
│  - Moves completed items to "Working"                    │
│  - Updates "In Progress"                                 │
│  - Adds new "To Do" items discovered during session      │
└──────────────────────────────────────────────────────────┘
```

## The Three Memory Files

### corrections.md — "Don't do that again"

When you correct Claude, it logs the correction. Next session, the hook injects active corrections so Claude doesn't repeat the same mistake.

**Example content:**

```markdown
| Date | What | Error | Correction |
|------|------|-------|------------|
| 2026-04-01 | DB tests | Mocked the database | Use real DB — mocks masked a broken migration last quarter |
| 2026-04-02 | API routes | Used default exports | Named exports only — project convention |
| 2026-04-03 | Error handling | Added try/catch everywhere | Only validate at system boundaries, trust internal code |
```

**What this prevents:** Claude making the same mistake 5 sessions in a row because it has no memory of being corrected. The correction rate goes from ~0% (no memory) to ~85-90% (corrections file loaded at start).

### decisions.md — "We already decided this"

Architectural decisions with their rationale and rejected alternatives. Prevents Claude from re-proposing something you've already considered and rejected.

**Example content:**

```markdown
| Date | Decision | Why | Rejected alternatives |
|------|----------|-----|----------------------|
| 2026-03-15 | PostgreSQL + pgvector | Need concurrent writes + vector search for RAG | SQLite (no pgvector), MongoDB (team has no experience) |
| 2026-03-20 | Gemini for embeddings | Cost effective, 768D vectors, good enough quality | OpenAI (3x cost), local models (too slow for prod) |
| 2026-04-01 | Monorepo | Frontend and backend share types, deploy together | Separate repos (added complexity for 2-person team) |
```

**What this prevents:** "Have you considered using MongoDB instead?" for the fifth time. Or Claude proposing a microservice architecture after you explicitly chose a monolith.

### status.md — "Here's where we are"

A living document of what works, what's in progress, and what's pending. Updated at the end of each session.

**Example content:**

```markdown
## Working
- Auth flow (login, register, JWT, password reset)
- Chat interface with SSE streaming
- RAG pipeline (embeddings + pgvector search)
- Docker deployment with Caddy reverse proxy

## In Progress
- File upload endpoint (PDF/DOCX extraction)
  - pandoc installed in Docker, API route created
  - TODO: wire up to chat input UI

## To Do
- Payment integration (Stripe or LemonSqueezy)
- Admin dashboard
- Rate limiting per plan
- Email templates (password reset, welcome)
```

**What this prevents:** Claude spending 5 minutes exploring the codebase to figure out what works and what doesn't. Or asking "what should I work on?" when the answer is already written down.

## The CLAUDE.md Template

The init script creates a `CLAUDE.md` with a standard structure. The most important section is **Persistent Memory**, which contains six explicit rules:

```markdown
## Persistent Memory

### Rules for Claude

1. **Before acting:** check corrections.md — if you made this mistake before, don't repeat it.
2. **Before proposing alternatives:** check decisions.md — if a decision was already made
   with rationale, don't re-debate it unless the user asks.
3. **When the user corrects you:** add a row to corrections.md with the date, what happened,
   and the correction.
4. **When an architectural decision is made:** add a row to decisions.md with the date,
   decision, rationale, and what was considered but rejected.
5. **At end of session:** update status.md — move completed items to "Working", update
   "In Progress", add new "To Do" items discovered during the session.
6. **Don't over-document:** only log corrections that could recur and decisions that matter.
   Skip trivial or one-off issues.
```

These rules are loaded by Claude Code automatically (CLAUDE.md is always in context). The hook then provides the *data* these rules operate on.

## Existing Projects

If your project already has a `CLAUDE.md`, the init script won't overwrite it. It will:
- Create `.claude-memory/` with the three files
- Create the hook
- Warn you to add the memory rules to your existing CLAUDE.md

You can copy the "Persistent Memory" section from the template into your existing CLAUDE.md.

## When settings.json Already Exists

If `.claude/settings.json` already exists (e.g., you have other hooks configured), the script won't overwrite it. It will print the hook configuration to add manually:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-orient.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## Comparison

| | claude-project-memory | [OpenWolf](https://github.com/gsd-build/openwolf) | Raw CLAUDE.md only |
|---|---|---|---|
| **Setup** | 1 command | npm install + init | Manual |
| **Memory files** | 3 (corrections, decisions, status) | 5+ (anatomy, cerebrum, memory, buglog, ledger) |  0 |
| **Hooks** | 1 (session start) | 6 (pre/post read/write + start/stop) | 0 |
| **Token overhead** | ~20 lines injected at start | Varies, can be significant per tool call | 0 |
| **Dependencies** | Bash only | Node.js runtime + daemon process | None |
| **Focus** | What matters for decisions | File read tracking + token optimization | — |
| **Complexity** | Minimal | Heavy | Minimal |

**When to use claude-project-memory:** you want Claude to remember your corrections, respect your decisions, and know where the project stands — without overhead.

**When to use OpenWolf:** you're optimizing for token cost on a large codebase and want file-level read tracking, deduplication, and token accounting.

**They're complementary**, not competing. You could use both.

## Philosophy

- **3 files > 10 files.** Most teams won't maintain 10 memory files. Three files that actually get used beat ten that get ignored.
- **Markdown > JSON.** You should be able to read and edit memory in any text editor. No special tooling required.
- **Convention > enforcement.** CLAUDE.md tells Claude what to do. It's not a hard technical constraint — it's a strong convention that works because Claude follows instructions well.
- **Personal > shared.** Memory is gitignored because corrections and status are specific to your development flow, not the project itself. Two developers on the same project will have different corrections.
- **Lightweight > comprehensive.** The hook injects ~20 lines of context. That's negligible in a 200K token context window but enough to change Claude's behavior meaningfully.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Bash
- Git (optional — the hook shows git status if available)

## FAQ

**Does this work with other AI coding tools (Cursor, Copilot, Codex)?**
The memory files and CLAUDE.md work with any tool that reads markdown instructions. The hook is Claude Code-specific, but the concept is portable.

**Should I commit .claude-memory/ to the repo?**
No — it's gitignored by default. Memory is personal to your workflow. If you want shared project memory, put it in CLAUDE.md instead.

**How big do the memory files get?**
In practice, corrections.md stays under 30 rows (old corrections become habits and can be pruned). decisions.md grows slowly (big decisions are infrequent). status.md is rewritten each session, so it stays current and compact.

**Can I customize the hook?**
Absolutely. The hook is a bash script in your project — add whatever context is useful (database stats, test results, deploy status, etc.).

## License

MIT
