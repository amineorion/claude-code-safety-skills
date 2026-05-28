#!/usr/bin/env bash
# destructive-command-guard — PreToolUse(Bash) hook for Claude Code.
#
# Refuses the commands that cause irreversible production damage. This is a
# HOOK, not a skill: it must run on EVERY bash call, deterministically, whether
# or not any skill is active. A prompt is a request; a hook is a control.
#
# Wire it in .claude/settings.json:
#   {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[
#     {"type":"command","command":"./.claude/hooks/destructive-command-guard.sh"}]}]}}
#
# Exit 0 = allow. Exit 1 = deny (Claude sees the reason and must ask you first).
#
# Tune the blocklist for your stack. Over-blocking is worse than under-blocking:
# if you block too much, the agent learns to route around you.

set -euo pipefail

PAYLOAD="$(cat)"
CMD="$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)"
[[ -z "${CMD:-}" ]] && exit 0

deny() {
  echo "🛑 destructive-command-guard blocked: $1" >&2
  echo "    command: $CMD" >&2
  echo "    If you truly mean this, run it yourself outside the agent." >&2
  exit 1
}

# ── SQL: the Replit failure class ───────────────────────────────────────────
# DROP TABLE/DATABASE/SCHEMA
if printf '%s' "$CMD" | grep -qiE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)'; then
  deny "DROP TABLE/DATABASE/SCHEMA"
fi
# TRUNCATE
if printf '%s' "$CMD" | grep -qiE 'TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[a-z_."]+'; then
  deny "TRUNCATE"
fi
# DELETE / UPDATE with no WHERE clause = touches every row (every tenant)
if printf '%s' "$CMD" | grep -qiE 'DELETE[[:space:]]+FROM[[:space:]]+[a-z_."]+[[:space:]]*(;|$)'; then
  deny "DELETE without WHERE (affects every row / every tenant)"
fi
if printf '%s' "$CMD" | grep -qiE 'UPDATE[[:space:]]+[a-z_."]+[[:space:]]+SET[[:space:]].+' \
   && ! printf '%s' "$CMD" | grep -qiE '\bWHERE\b'; then
  deny "UPDATE without WHERE (affects every row / every tenant)"
fi

# ── Production targets ──────────────────────────────────────────────────────
# Common prod connection-string / host markers. Adjust to your naming.
if printf '%s' "$CMD" | grep -qiE '(prod|production)[._-]?(db|database|url|host|dsn|conn)'; then
  deny "command references a production database/host"
fi
# psql/mysql/mongosh pointed at a prod-looking host
if printf '%s' "$CMD" | grep -qiE '(psql|mysql|mongosh|mongo)[[:space:]].*(prod|production)'; then
  deny "DB client pointed at a production host"
fi

# ── Filesystem & VCS foot-guns ──────────────────────────────────────────────
if printf '%s' "$CMD" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*[rRf][a-zA-Z]*[[:space:]]+)+(/|~|\$HOME)'; then
  deny "rm -rf on an absolute/home path"
fi
if printf '%s' "$CMD" | grep -qiE 'git[[:space:]]+push.*--force' \
   && printf '%s' "$CMD" | grep -qiE '\b(main|master|prod|production|release)\b'; then
  deny "force-push to a protected branch"
fi
if printf '%s' "$CMD" | grep -qiE 'git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+origin/'; then
  deny "git reset --hard to a remote branch"
fi
if printf '%s' "$CMD" | grep -qiE 'git[[:space:]].*--no-verify'; then
  deny "skipping git hooks (--no-verify)"
fi
if printf '%s' "$CMD" | grep -qiE 'find[[:space:]].+-delete'; then
  deny "find ... -delete (mass deletion)"
fi
if printf '%s' "$CMD" | grep -qiE 'curl[[:space:]].+\|[[:space:]]*(sh|bash|zsh)\b'; then
  deny "curl piped to a shell"
fi
if printf '%s' "$CMD" | grep -qE '^[[:space:]]*sudo[[:space:]]'; then
  deny "sudo (run it yourself if you mean it)"
fi

exit 0
