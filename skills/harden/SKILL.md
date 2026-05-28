---
name: harden
description: Install the always-on safety hooks (destructive-command-guard + tenant-scope-guard) into this project. Use when setting up a multi-tenant or production codebase for agent-authored changes, or when the user asks to "harden", "add safety hooks", or "guard prod".
disable-model-invocation: true
allowed-tools: Bash(bash *) Bash(cp *) Bash(chmod *) Bash(mkdir *) Read Edit
---

# Harden this project

Install the two deterministic guards that block irreversible damage. These run as
**hooks**, not skills, because they must fire on every action regardless of what is
loaded. A prompt is a request; a hook is a control.

## Steps

1. Run the installer to copy the hook scripts into `.claude/hooks/`:

   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/install.sh
   ```

2. Merge the printed snippet into `.claude/settings.json` under `"hooks"`. If a
   `hooks` block already exists, merge the arrays — do not overwrite.

3. Tell the user what got wired, and remind them to tune the blocklists:
   - `destructive-command-guard.sh` — review the SQL and prod-host patterns for their stack.
   - `tenant-scope-guard.sh` — set `TENANT_COL` if their tenant column isn't one of
     `tenant_id|org_id|account_id|workspace_id`.

## What each guard does

- **destructive-command-guard** (PreToolUse/Bash): refuses `DROP`/`TRUNCATE`,
  `DELETE`/`UPDATE` without `WHERE`, commands aimed at a production host, force-push
  to protected branches, `rm -rf` on absolute paths, `curl | sh`, and `sudo`.
- **tenant-scope-guard** (PostToolUse/Edit): warns when a freshly edited data-access
  line has no visible tenant filter — the missed `WHERE tenant_id` that becomes a leak.

Over-blocking is worse than under-blocking: if a guard is too aggressive the agent
learns to route around it. Keep the lists short and high-signal.
