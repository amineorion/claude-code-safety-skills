---
name: two-tenant-verify
description: Verify tenant isolation by exercising a data change as a second tenant and confirming the first tenant's data is invisible — in the running app, not just tests. Use after changing data-access code on a multi-tenant SaaS, before merging, or when the user asks to prove isolation holds or test for leaks end to end.
allowed-tools: Read Grep Glob Bash
---

# Two-tenant verification

Green tests are not proof of isolation. A test fixture with one tenant will pass even
when a query has no tenant filter at all, because there is only one tenant's data to
return. The only honest check uses **two** tenants.

## The rule

> A data change is done when you have logged in as a second tenant and confirmed the
> first tenant's data is invisible — in the running app, not just green tests.

## Procedure

1. **Seed two tenants.** Adapt the template at
   `${CLAUDE_SKILL_DIR}/scripts/seed-two-tenants.sql.template` to the project schema.
   Each tenant gets one clearly-labeled secret row (`SECRET-A`, `SECRET-B`).

2. **Boot the stack against the seeded data.** Use the project's `scripts/dev.sh`
   (or create a one-command launcher if none exists — the friction is why this step
   gets skipped).

3. **Exercise the changed path as Tenant B.** Authenticate as `user-b@example.com` and
   hit the exact endpoint/page/job the change touched.

4. **Assert the boundary, both directions:**
   - As Tenant B, you can see `SECRET-B` and **never** `SECRET-A`.
   - As Tenant A, you can see `SECRET-A` and **never** `SECRET-B`.
   - Check the response body, not just the UI — leaked data sometimes renders blank
     but is present in the payload, cache, or search results.

5. **Cover the non-DB vectors** the change touched: trigger the background job and
   confirm it only processed Tenant B's rows; check that cached responses aren't shared;
   confirm search returns only the caller's tenant.

## Report

State exactly what you exercised and what you observed, e.g.:
"Logged in as Tenant B, opened /documents and the export job: saw SECRET-B only,
SECRET-A absent from the page, JSON payload, and the export file. Isolation holds."
If you could not run the app, say so — do not infer isolation from reading code.
