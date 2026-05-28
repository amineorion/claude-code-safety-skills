#!/usr/bin/env bash
# install.sh — copy the safety hooks into the current project's .claude/hooks/
# and print the settings.json snippet to merge. Idempotent.
#
# Usage: bash ${CLAUDE_SKILL_DIR}/scripts/install.sh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST=".claude/hooks"
mkdir -p "$DEST"

for s in destructive-command-guard.sh tenant-scope-guard.sh; do
  cp "$SKILL_DIR/$s" "$DEST/$s"
  chmod +x "$DEST/$s"
  echo "installed: $DEST/$s"
done

cat <<'JSON'

── Merge this into .claude/settings.json (under "hooks") ──────────────────────
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "./.claude/hooks/destructive-command-guard.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|MultiEdit", "hooks": [
        { "type": "command", "command": "./.claude/hooks/tenant-scope-guard.sh" } ] }
    ]
  }
}
───────────────────────────────────────────────────────────────────────────────
If settings.json already has a "hooks" block, merge the arrays rather than replace.
JSON
