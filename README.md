# claude-code-safety-skills

The production-safety skill suite for Claude Code. For engineers who let an AI agent
write code in a **multi-tenant SaaS with real paying customers** — where one missed
`WHERE tenant_id` is a data breach, not a bug, and one `DROP TABLE` is a very bad day.

In 2025 an AI agent [deleted a company's production database during a code freeze](https://www.tomshardware.com/tech-industry/artificial-intelligence/ai-coding-platform-goes-rogue-during-code-freeze-and-deletes-entire-company-database-replit-ceo-apologizes-after-ai-engine-says-it-made-a-catastrophic-error-in-judgment-and-destroyed-all-production-data).
This is the kit that makes that failure class structurally hard, instead of something
you hope the agent remembers not to do.

## What's in here

| Item | Type | What it does |
|---|---|---|
| `harden` | skill (manual) | Installs the two always-on hooks below into your project |
| `destructive-command-guard` | **hook** | Refuses `DROP`/`TRUNCATE`, `DELETE`/`UPDATE` without `WHERE`, prod-targeted commands, force-push, `rm -rf`, `curl \| sh` |
| `tenant-scope-guard` | **hook** | Warns the instant a freshly edited file has a query missing a tenant filter |
| `tenant-scope-audit` | skill | Scans the repo (or a diff) for unscoped data access — and the cache/job/search vectors RLS misses |
| `cross-tenant-leak-reviewer` | skill (forked) | Fresh-eyes review of your diff for cross-tenant leaks before merge |
| `migration-safety-check` | skill | Reviews a migration before it runs against every tenant at once |
| `two-tenant-verify` | skill | Proves isolation in the running app with two seeded tenants |

**Why some are hooks, not skills:** always-on blocking has to be deterministic, so it's
a hook (a control). Audits and reviews are judgment calls, so they're skills (procedures
Claude runs). Knowing which is which is half the discipline.

## Install

Drop the skills into your project (per-project) or your home dir (all projects):

```bash
# this project only
git clone https://github.com/amineorion/claude-code-safety-skills /tmp/ccss
cp -r /tmp/ccss/skills/* .claude/skills/

# then wire the always-on hooks
/harden
```

`/harden` copies the hook scripts into `.claude/hooks/` and prints the `settings.json`
snippet to merge. Tune the blocklists for your stack (set `TENANT_COL` if your tenant
column isn't `tenant_id`).

## Use

```
/tenant-scope-audit                  # scan the whole repo for unscoped access
/cross-tenant-leak-reviewer          # review the current diff before you merge
/migration-safety-check migrations/0042_add_column.sql
/two-tenant-verify                   # prove isolation end-to-end in the running app
```

Or just work — `tenant-scope-audit` and the reviewer auto-trigger when you touch
multi-tenant data code, because their descriptions say so.

## Tune before you trust

These are high-signal heuristics, not proofs. Read each script, adjust the patterns to
your stack, and remember: over-blocking is worse than under-blocking — if a guard is too
aggressive, the agent learns to route around it.

## The reasoning behind every piece

Full writeup: [6 guardrails that stop Claude Code from breaking your multi-tenant SaaS](https://palaheal.dev/pillar-1.html).
If you want the next post and first access when repo-audit slots open, drop your email at
[palaheal.dev](https://palaheal.dev).

## License

MIT. Fork it, ship it, tune it. A link back to [palaheal.dev](https://palaheal.dev) is
appreciated, not required.
