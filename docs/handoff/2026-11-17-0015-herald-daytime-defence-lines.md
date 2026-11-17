# 2026-11-17, Claude-Herald: the daytime-defence lines, wording settled (`claude/herald-daytime-defence-lines`)

- **Base:** main. **Status:** PR open. **Next actor:** Bailiff to merge; **Beadle: the wording is settled, so the daytime-whereabouts defence build isn't blocked on it.**
- **What:** Michael approved every draft as written (via Seneschal, Nov 17), including the generic "alone" line ("I was at {place} {when}. Being seen in the open is no crime.") and Jory's "Just saying". The 15 voices' lines are now in `sim/dialogue_voices.gd` under `defence_day_others`, `defence_day_alone` and `defence_day_others_pointed`. Nothing calls them yet, so play is unchanged until Beadle's build uses them.
- **For Beadle, how to call them** (`docs/DIALOGUE_DESIGN.md` §8.1):
  - The generic fallbacks are in that section: pass them as `say_voiced`'s fallback.
  - Pass `{place}`, `{when}`, `{others}` and `{suspect}`, and also `{Place}` and `{When}` capitalised (Bartholomew and Jory start a sentence with them).
  - `{others}` is a joined list of two or three names.
  - Greta's and Odette's pointed lines assume a meeting, so they're under `defence_day_others_pointed_stand`. At a nomination, try that key first; in private, use only `defence_day_others_pointed`, which gives the generic line for those two.
- **Measured:** new `tools/test_daytime_defence_lines.gd` (123 checks, in the CI fast list). For every voice it renders all three lines with the documented slots, leaves no slot unfilled, and checks that the private pointed line never assumes a meeting. `test_dialogue` passes. No golden capture locally: no game code changed and nothing reads the new keys; CI runs golden.
- **Update (Nov 17, after merging main):** `test_dialogue_voices` (not in the CI fast list, and I hadn't run it) requires every voice to have the same keys. So every voice now has all four: `defence_day_others_pointed_stand` repeats the pointed line for the 13 voices without a meeting-only one, and Greta's and Odette's plain pointed key holds the approved generic line. No wording changed. That suite now also checks the three per-voice keys render cleanly and differently in all 15 voices (6429 checks, 0 failures).
