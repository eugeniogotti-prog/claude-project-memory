#!/bin/bash
# claude-project-memory — init.sh
# Lightweight persistent memory for Claude Code projects.
# Usage: curl -fsSL https://raw.githubusercontent.com/eugeniogotti-prog/claude-project-memory/main/init.sh | bash

set -e

echo "🧠 claude-project-memory — initializing..."

# 1. Create directories
mkdir -p .claude/hooks .claude-memory

# 2. Create empty memory files
cat > .claude-memory/corrections.md << 'EOF'
# Corrections

Mistakes corrected by the user. Claude reads this file at session start to avoid repeating errors.

| Date | What | Error | Correction |
|------|------|-------|------------|
EOF

cat > .claude-memory/decisions.md << 'EOF'
# Architectural Decisions

Decisions made and their rationale. Prevents re-debating settled choices.

| Date | Decision | Why | Rejected alternatives |
|------|----------|-----|----------------------|
EOF

cat > .claude-memory/status.md << 'EOF'
# Project Status

Current state — updated at end of each session.

## Working


## In Progress


## To Do

EOF

# 3. Create session orientation hook
cat > .claude/hooks/session-orient.sh << 'HOOKEOF'
#!/bin/bash
# Injects memory and project state at session start.
# Also re-injects working state if session restarted after context compaction.

echo "=== PROJECT ORIENTATION ==="

# Re-inject working state after compaction
if [ "${CLAUDE_CONTEXT_SOURCE}" = "compact" ] && [ -f .claude-memory/working-state-rescue.md ]; then
  echo ""
  echo "--- WORKING STATE (restored after compaction) ---"
  cat .claude-memory/working-state-rescue.md
  rm .claude-memory/working-state-rescue.md
fi

if [ -f .claude-memory/status.md ]; then
  echo ""
  echo "--- PROJECT STATUS ---"
  cat .claude-memory/status.md
fi

if [ -f .claude-memory/corrections.md ]; then
  CORRECTIONS=$(grep '^|' .claude-memory/corrections.md | grep -v '^| Date' | grep -v '^|---')
  if [ -n "$CORRECTIONS" ]; then
    echo ""
    echo "--- ACTIVE CORRECTIONS ---"
    echo "$CORRECTIONS"
  fi
fi

if [ -f .claude-memory/decisions.md ]; then
  DECISIONS=$(grep '^|' .claude-memory/decisions.md | grep -v '^| Date' | grep -v '^|---')
  if [ -n "$DECISIONS" ]; then
    echo ""
    echo "--- ARCHITECTURAL DECISIONS ---"
    echo "$DECISIONS"
  fi
fi

echo ""
echo "--- GIT ---"
git log --oneline -5 2>/dev/null || echo "(not a git repo)"
BRANCH=$(git branch --show-current 2>/dev/null)
[ -n "$BRANCH" ] && echo "Branch: $BRANCH"
DIRTY=$(git status --porcelain 2>/dev/null | head -5)
[ -n "$DIRTY" ] && echo "Modified:" && echo "$DIRTY"

echo ""
echo "=== END ORIENTATION ==="
HOOKEOF
chmod +x .claude/hooks/session-orient.sh

# 4. Create pre-compact hook (saves working state before context compaction)
cat > .claude/hooks/pre-compact.sh << 'HOOKEOF'
#!/bin/bash
# Saves working state before Claude's context is compacted.
# session-orient.sh re-injects it when CLAUDE_CONTEXT_SOURCE == compact.
RESCUE=".claude-memory/working-state-rescue.md"
echo "# Working-state rescue — $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RESCUE"
echo "" >> "$RESCUE"
echo "## Recently modified files" >> "$RESCUE"
git diff --name-only 2>/dev/null | head -20 >> "$RESCUE"
git status --porcelain 2>/dev/null | grep '^?' | awk '{print $2}' | head -10 >> "$RESCUE"
HOOKEOF
chmod +x .claude/hooks/pre-compact.sh

# 5. Create or update .claude/settings.json
if [ -f .claude/settings.json ]; then
  if ! grep -q "session-orient" .claude/settings.json; then
    echo ""
    echo "⚠️  .claude/settings.json already exists."
    echo "   Add these hooks manually:"
    echo '   SessionStart: {"type":"command","command":".claude/hooks/session-orient.sh","timeout":10}'
    echo '   PreCompact:   {"type":"command","command":".claude/hooks/pre-compact.sh","timeout":10}'
  else
    echo "ℹ️  Hook already configured in .claude/settings.json"
  fi
else
  cat > .claude/settings.json << 'EOF'
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
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pre-compact.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF
fi

# 6. Create CLAUDE.md template if it doesn't exist
if [ ! -f CLAUDE.md ]; then
  PROJECT_NAME=$(basename "$(pwd)")
  cat > CLAUDE.md << MDEOF
# CLAUDE.md — ${PROJECT_NAME}

[Project description in 1-2 sentences]

## Stack

- **Language:**
- **Framework:**
- **Database:**
- **Deploy:**

## Architecture

[Main directory structure and what each part does]

## Conventions

- [Naming, style, patterns to follow]

## Useful Commands

\`\`\`bash
# Build
# Test
# Deploy
\`\`\`

## Persistent Memory

Claude reads these files automatically at session start via the \`session-orient.sh\` hook:

| File | Purpose | When to update |
|------|---------|----------------|
| \`.claude-memory/status.md\` | What works, what's in progress, what's next | End of every session |
| \`.claude-memory/corrections.md\` | Mistakes to not repeat | When user corrects an error |
| \`.claude-memory/decisions.md\` | Architecture decisions with rationale | When a decision is made |

### Rules for Claude

1. **Before acting:** check \`corrections.md\` — if you made this mistake before, don't repeat it.
2. **Before proposing alternatives:** check \`decisions.md\` — if a decision was already made with rationale, don't re-debate it unless the user asks.
3. **When the user corrects you:** add a row to \`corrections.md\` with the date, what happened, and the correction.
4. **When an architectural decision is made:** add a row to \`decisions.md\` with the date, decision, rationale, and what was considered but rejected.
5. **At end of session:** update \`status.md\` — move completed items to "Working", update "In Progress", add new "To Do" items discovered during the session.
6. **Don't over-document:** only log corrections that could recur and decisions that matter. Skip trivial or one-off issues.
MDEOF
  echo "✅ CLAUDE.md created (fill in your project details)"
else
  echo "ℹ️  CLAUDE.md already exists, not overwritten"
  if ! grep -q "Persistent Memory" CLAUDE.md; then
    echo ""
    echo "⚠️  Your CLAUDE.md doesn't have a 'Persistent Memory' section."
    echo "   Consider adding the memory rules. See the template in the repo."
  fi
fi

# 7. Update .gitignore
if [ -f .gitignore ]; then
  grep -q '.claude-memory/' .gitignore 2>/dev/null || echo '.claude-memory/' >> .gitignore
  grep -q '.claude/settings.local.json' .gitignore 2>/dev/null || echo '.claude/settings.local.json' >> .gitignore
else
  printf '.claude-memory/\n.claude/settings.local.json\n' > .gitignore
fi

echo ""
echo "✅ claude-project-memory initialized!"
echo ""
echo "   Files created:"
echo "   - CLAUDE.md                    → fill in your project details"
echo "   - .claude-memory/              → persistent memory (gitignored)"
echo "   - .claude/hooks/session-orient.sh  → injects memory at session start"
echo "   - .claude/hooks/pre-compact.sh     → saves working state before compaction"
echo ""
echo "   Next: open CLAUDE.md and add your stack, architecture, conventions."
