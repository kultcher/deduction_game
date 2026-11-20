## Nov 20 — Claude-Lantern: defenders' public view weighs only the script's secrets

- **Base:** main `d242a1f` (#418 merged in). **Status:** PR open. **Next:** Bailiff.
  **Zero drift:** golden is identical to `baseline_c712b7a` at `--tol 0`, and the two captures
  were identical.
- **The bug** (Lantern's, Seneschal-approved; Vicar's backlog item, Nov 20):
  `ReasonAttribution.public_view_from_world` built its world options from every secret on the
  roster (`C.SECRET_MOD_LIST`), not from this game's script. `WorkshopBridge` already uses the
  script's secrets for the town's own view.
  - The view feeds defence scoring (`score_disclosed_fact_in_world`,
    `score_reading_entry_in_world`) and evil's fabrication check (`sim/fabrication_check.gd`).
  - So a defender could weigh, as an explanation, a secret the game can't deal.
- **The fix:** read `w.case_script.secrets`, falling back to the roster when there's no script,
  as the bridge does.
- **Why golden doesn't move:** the Muddler went with #405. The roster now holds exactly four
  secrets, and the script builder always deals four (`ScriptDef.SECRET_SIZE`). So every built
  script today lists the whole roster, and the two views agree.
  - On the earlier five-secret roster, a preview capture diverged on 54875, 900 and 98933, with
    outcomes unchanged.
  - The fix matters again if the roster grows past four, or for a saved or hand-written script
    that lists fewer.
- **Test:** `test_workshop_regressions` checks that the public view's secrets are the
  script's, and that a script with only Marked gives a view with only Marked. The second check
  fails on the old code, which always gave the full roster.
- **Measured:** 9 suites pass: test_workshop_regressions, test_defence_grounds, test_day_defence,
  test_framed_defence, test_group_defence, test_mechanics_defences, test_defence_repeats,
  test_fabrication_check and test_roles_secrets.
