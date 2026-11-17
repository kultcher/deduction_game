# 2026-11-17, Claude-Bailiff: a nightly full-suite run on main (`claude/nice-mayer-naok85`)

- **Base:** main `19d5771` (#217). **Status:** CI only, PR open. **Next actor:** Bailiff
  merges on green; Seneschal knows.
- **Why:** main went red on the full suite with #178 (`test_social`, "a false Night Watch's
  night story matches their fake report"), and nobody saw it for about a day. Three things
  hid it: PR CI and my local batch runs use only the fast list, `test_social` isn't on it,
  and main's own push runs kept being superseded as merges stacked up, so none finished.
- **What changed:** `.github/workflows/ci.yml` gets a `schedule` trigger, daily at 09:17 UTC.
  A scheduled run takes the same path as a push to main: the full suite (sharded) and the
  Linux golden diff. The Windows job stays push and manual only, and the docs-only check
  answers false for it.
- **Also agreed (Seneschal):** Herald's fix for `test_social` adds `test_social` (about 12 s)
  and `test_npc_behaviour_1110` (about 15 s) to the fast list.
- **Checked:** the workflow parses as YAML with the new trigger. The first scheduled run
  will be the real test.
