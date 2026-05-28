#!/usr/bin/env bash
# tenant-scope-guard — PostToolUse(Edit|Write|MultiEdit) hook for Claude Code.
#
# Warns when a freshly edited file contains a data query that looks unscoped —
# the missed `WHERE tenant_id` that turns into a cross-tenant leak. It's a
# heuristic (regex), not a proof. It fires at the moment the code is written,
# when the fix is free.
#
# Wire it in .claude/settings.json:
#   {"hooks":{"PostToolUse":[{"matcher":"Edit|Write|MultiEdit","hooks":[
#     {"type":"command","command":"./.claude/hooks/tenant-scope-guard.sh"}]}]}}
#
# Exit 0 = pass. Exit 2 = warn (Claude sees the message and should fix it).
# Configure the tenant column name with TENANT_COL (default: tenant_id|org_id|account_id|workspace_id).

set -euo pipefail

PAYLOAD="$(cat)"
FILE="$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys; t=json.load(sys.stdin).get("tool_input",{}); print(t.get("file_path") or t.get("filePath") or "")' 2>/dev/null || true)"
[[ -z "${FILE:-}" || ! -f "$FILE" ]] && exit 0

# Only inspect code likely to touch data.
case "$FILE" in
  *.py|*.ts|*.js|*.tsx|*.jsx|*.go|*.rb|*.sql) : ;;
  *) exit 0 ;;
esac

TENANT_COL="${TENANT_COL:-tenant_id|org_id|account_id|workspace_id}"

# Lines that read/write a table but mention no tenant column and no WHERE.
# Heuristic: a SELECT/UPDATE/DELETE or ORM .query/.find that lacks the column.
hits="$(grep -nEi '(SELECT[[:space:]].+FROM|UPDATE[[:space:]]|DELETE[[:space:]]+FROM|\.query\(|\.find\(|\.findMany\(|\.filter\()' "$FILE" 2>/dev/null \
  | grep -viE "($TENANT_COL)" \
  | grep -viE 'for_tenant|tenant_scoped|scoped_to|with_tenant|set_config.*tenant|RLS|row.security' \
  | head -5 || true)"

if [[ -n "$hits" ]]; then
  echo "⚠️  tenant-scope-guard: possible UNSCOPED data access in $FILE" >&2
  echo "    These lines query data without a visible tenant filter ($TENANT_COL):" >&2
  printf '%s\n' "$hits" | sed 's/^/      /' >&2
  echo "    Confirm each is tenant-scoped (or routed through your tenant-safe repo layer)." >&2
  echo "    Caches, background jobs, and search indexes are NOT covered by row-level security." >&2
  exit 2
fi

exit 0
