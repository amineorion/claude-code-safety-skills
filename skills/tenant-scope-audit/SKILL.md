---
name: tenant-scope-audit
description: Audit a multi-tenant codebase for queries, caches, jobs, or searches that are missing a tenant filter — the missed WHERE tenant_id that becomes a cross-tenant data leak. Use whenever the user works on a multi-tenant SaaS, asks to check tenant isolation, reviews data-access code, or mentions tenant scoping, RLS, or data leaks.
allowed-tools: Bash(bash *) Bash(git *) Read Grep Glob
---

# Tenant-scope audit

Find data access that is not scoped to a tenant. In a shared-schema multi-tenant
system, one unscoped query is a data breach, not a performance bug.

## Run the scan

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scan-tenant-scope.sh
```

Scope it to a path or the current diff when reviewing a change:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scan-tenant-scope.sh api/ workers/
```

Set `TENANT_COL` if the tenant column isn't `tenant_id|org_id|account_id|workspace_id`.

## Then reason about each hit

The scanner is a heuristic. For every flagged line, decide which case it is:

1. **Genuinely unscoped (fix it)** — a query that returns rows across tenants.
   The fix is a tenant filter, or routing through the tenant-safe data layer.
2. **Scoped indirectly (verify, then note)** — row-level security, a `for_tenant()`
   repository, or a `current_setting('app.tenant_id')` is enforcing it. Confirm the
   enforcement actually covers this path.
3. **Intentionally global (document it)** — an admin/reporting query that must span
   tenants. It needs an explicit comment and ideally a separate, audited code path.

## Look past the database — RLS does not cover these

Row-level security is a safety net, not a fortress wall. Check the vectors it misses:

- **Caches** — is the cache key namespaced by tenant? A shared key serves tenant A's
  data to tenant B.
- **Background jobs** — are queues/global workers filtering by tenant, or exporting
  every tenant's rows?
- **Search indexes** — are documents written and queried with a tenant key?
- **File paths / blob storage** — are object keys prefixed by tenant?

## Report

Summarize as: confirmed leaks (with file:line and the fix), needs-verification, and
documented-global. Lead with anything that returns other tenants' data today.
