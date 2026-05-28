#!/usr/bin/env bash
# scan-tenant-scope.sh — list data-access lines that have no visible tenant filter.
#
# Usage:
#   scan-tenant-scope.sh                 # scan all git-tracked code files
#   scan-tenant-scope.sh path/ file.py   # scan specific paths
#   TENANT_COL='tenant_id|org_id' scan-tenant-scope.sh
#
# Heuristic, not proof. Output is file:line: <code>. Empty output = nothing flagged.
set -euo pipefail

TENANT_COL="${TENANT_COL:-tenant_id|org_id|account_id|workspace_id}"
SAFE='for_tenant|tenant_scoped|scoped_to|with_tenant|set_config.*tenant|RLS|row.?security|current_setting'
QUERY='(SELECT[[:space:]].+FROM|UPDATE[[:space:]]+[a-z_."]+[[:space:]]+SET|DELETE[[:space:]]+FROM|\.query\(|\.execute\(|\.find\(|\.findMany\(|\.findFirst\(|\.filter\(|\.where\()'

# Build file list.
if [[ $# -gt 0 ]]; then
  files=$(find "$@" -type f \( -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.go' -o -name '*.rb' -o -name '*.sql' \) 2>/dev/null || true)
else
  files=$(git ls-files '*.py' '*.ts' '*.js' '*.tsx' '*.jsx' '*.go' '*.rb' '*.sql' 2>/dev/null || true)
fi
[[ -z "$files" ]] && { echo "(no code files found to scan)"; exit 0; }

count=0
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  while IFS= read -r line; do
    echo "$f:$line"
    count=$((count+1))
  done < <(grep -nEi "$QUERY" "$f" 2>/dev/null \
            | grep -viE "($TENANT_COL)" \
            | grep -viE "$SAFE" || true)
done <<< "$files"

echo "---"
echo "flagged: $count line(s) with no visible tenant filter"
echo "Review each: confirm it is tenant-scoped, routed through a tenant-safe layer, or genuinely global (and document why)."
