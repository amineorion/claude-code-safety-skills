---
name: migration-safety-check
description: Review a database migration for safety before it runs against a multi-tenant production database, where one bad migration hits every customer at once. Use when the user writes, edits, or is about to run a migration, or asks whether a schema change is safe.
argument-hint: [migration-file]
allowed-tools: Read Grep Glob Bash(git *)
---

# Migration safety check

A migration in a multi-tenant system runs against **every tenant at once**. There is
no "blast radius of one." Review the migration (`$ARGUMENTS` if given, otherwise the
migration files in the current diff) against the checklist below and report each risk
with the specific line and a safer alternative.

## Destructive / irreversible

- Dropping a column or table — is the data backed up or is this truly dead? Is there a
  down-migration? Prefer a deprecate-then-drop across two releases.
- `DELETE`/`UPDATE` data migrations without a `WHERE`, or with a `WHERE` that doesn't
  bound the rows — this rewrites every tenant's data.
- Type changes / `NOT NULL` adds on a populated column — will they fail or lock on real
  data volumes?

## Locking & availability (you can't take all tenants down)

- Adding an index without `CONCURRENTLY` (Postgres) locks writes on a large table.
- `ALTER TABLE` that rewrites the table holds a lock proportional to row count.
- Long-running data backfills inside the schema migration — split them out and batch.

## Tenant correctness

- New tables: do they carry a tenant column and the right constraints/RLS policy from
  the start? A table that ships without tenant scoping is a future leak.
- Backfills: are they scoped/batched per tenant, or one statement across all rows?
- Defaults and unique constraints: are uniqueness scopes `(tenant_id, ...)` rather than
  global where they should be per-tenant?

## Process

- Is this migration applied by a human/CI on a schedule, never ad hoc by the agent?
- Has it been run against a copy of production-scale data, not just an empty dev DB?

## Output

```
VERDICT: SAFE TO APPLY | NEEDS CHANGES | DO NOT APPLY
BLOCKERS:
  - <line> — <risk> — <safer approach>
WARNINGS:
  - <line> — <risk> — <mitigation>
```
State the expected lock/rewrite behavior at production row counts, not just "looks fine."
