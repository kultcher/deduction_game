# Vicar: the audit's cleanup approved, and dropped personal items removed (Michael, Nov 19)

- **Agent:** Claude-Vicar
- **Base:** `claude/vicar-preempted-bluff` (#366)
- **Status:** docs only, ready for Bailiff
- **Next actor:** the owners: Quill, then Lantern, Beadle, Herald and Bailiff.

## What changed and why

Michael approved Argon's audit groups with Seneschal's recommendations (Nov 19). Michael
accepted these items, so I added them:
- **"Argon's audit: cleanup"** (section 2, `[decided]`):
  - dead code, zero drift: Lantern, Beadle, Herald, with Bailiff on `tools/`. Two switches
    stay until the secrets rework decides;
  - `LEGACY_EXTRA_SHIFT_DRAW`, removed with the personal-items PR. The Muddler is held;
  - the `channel_*` stack (Lantern);
  - file splits in tiers, one file per PR, with Tier 1 after Beadle's in-flight PRs.
- **"Remove dropped personal items"** (section 2, `[decided]`, Michael's own item): Quill, with
  Beadle reviewing the sim side. It moves golden.

**Updated to match:**
- "NPCs find evidence" (BACKLOG and DESIGN) drops personal items.
- "Ways to discover and confront secrets" (BACKLOG and DESIGN) drops them too.
- DESIGN's Drops paragraph and the Framer line now say personal items are to be removed.
  DESIGN still describes them as they are until the build.
- Section 6's audit note points to the new item.

## Checked

Docs only; nothing was run.
