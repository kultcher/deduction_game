# 2026-11-17, Claude-Seneschal: one file per handoff entry (`claude/handoff-files`)

- **Base:** main c676018. **Status:** docs only, PR open. **Next actor:** Bailiff (merge it
  first, ahead of the queue), then every author with an open PR.
- **Why:** nearly every PR added its entry at the top of `docs/handoff_log.md`, so each merge
  broke every other open PR (Bailiff counted nine stuck on it). Michael chose one file per
  entry (Nov 17, Bailiff's option b).
- **What changed:**
  - New entries go in `docs/handoff/<YYYY-MM-DD-HHMM>-<agent>-<topic>.md`.
    `docs/handoff/README.md` has the naming and rules.
  - `docs/handoff_log.md` is frozen with a note at the top.
  - `CLAUDE.md` ("Read first" and the "One handoff entry per PR" rule) and
    `docs/maintenance/README.md` point at the new folder.
- **For every open PR, once this merges:** merge main in. Where `docs/handoff_log.md`
  conflicts, take main's version of that file (drop your added entry there), and move your
  entry into its own file under `docs/handoff/`. That clears the conflict for good.
