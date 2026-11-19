# 2026-11-19, Claude-Lantern: a Warden's guard read with its night (`claude/warden-night-item`; moves golden)

- **Base:** main `634332e`, with main `a990916` merged in. **Status:** PR open, golden-moving.
  **Next:** Bailiff, in the golden queue.
- **Why:** Quill found it (Nov 19). A Warden's quiet-night guard cited with a sighting on the
  guarded block moved listeners no more than the sighting alone (+2.1 against +2.8, 10 seeds),
  while the Test juror counted it strongly.
- **Cause:** `Connections.NIGHT_ROLES` held only lamplighter and nightwatch. A guard report was
  its own item, weighed alone, so "the Demon came to this door"
  (`LiveActivity._quiet_guards`) never met "S was seen near it".
- **Fix:** `warden` joins `NIGHT_ROLES`. A listener's own Warden report now seeds the core like
  their own Night Watch or Lamplighter report.
- **Measured** (Quill's probe, his 10 seeds, the Demon as the subject; the listener's chance on
  them with the sighting alone and with the guard added):
  - **Sighting at full hearing weight:** the guard adds +0.01 to +0.03 before the fix, and +0.05
    to +0.07 after.
  - **As the listener hears an NPC's sighting (about 0.73):** −0.01 before, about 0 after. The
    town figure for sighting plus guard goes from +2.1 to +2.9, against +2.8 for the sighting
    alone.
  - **Why about 0:** the model reasons correctly. A doubted sighting leaves the guard alone, and
    alone it points away from S, who lives elsewhere.
  - **The juror's over-promise:** it hears every card at full weight. Michael has approved fixing
    that in the Test juror (Quill leads, with me and Herald).
- **Tests:** test_connections_pairings' grouping checks now include a Warden guard, in the night
  item and in the walker's movement connection. Both fail without the fix.
- **Suites:** 122/122 pass (the fast list plus test_warden_quiet_route, test_warden_challenge and
  test_connections), before main was merged in.
- **Golden:** see `docs/golden_baseline.md`, `baseline_e1d1934`. Only 692 moves; its nominator
  changes, the outcome doesn't.
- **Proposed for the backlog:** none.
