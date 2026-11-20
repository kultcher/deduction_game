## Nov 20 — Claude-Lantern: the "not the Demon" badge reads the chance of not being the Demon

- **Base:** main. **Status:** PR open. **Next:** Bailiff. Zero drift: golden never runs the Test
  juror.
- **The bug** (Seneschal's item, from Quill's premise check): for a "not the Demon" premise, the
  Test juror's badge read the subject's chance of being *good* (`WorkshopCanvas.listener_reading`
  took 1 − P(evil) for every clearing premise). But "not the Demon" also holds for a Minion. So:
  - **The badge could point the wrong way:** evidence that the subject is a Minion supports
    "not the Demon" but raises P(evil), so it read as "argues against".
  - **The top tier was undersold:** the chance of being good is never higher than the chance of
    not being the Demon.
- **The fix:** the average listener (connections) reports only P(evil), so the juror takes the
  share of that which is the Demon from CaseEval's reading of the same hearing (the "demon"
  question asked of the listener's own two Shared.prepare plans, through
  `SharedLedger.evaluate_question`), before and after. So the split weighs the same cards,
  hearing weights, route trust and challenges as the listener's chances (Codex's three findings
  on this PR: a challenged card stays, an accepted honest-mistake call discounts it, and a less
  trusting listener clears less). P(not Demon) = 1 − P(evil) ×
  P(Demon)/P(evil). The badge's strength and its top tier both read that.
  - New helper: `WorkshopCanvas._demon_share`. `profile_judge` also returns `plan_before`
    and `plan_after`.
  - No new constant or mechanic. Every other premise type is unchanged.
  - `TOP_TIER_CLEARS` keeps "notdemon" and now gets the right chance (Herald's request, so
    `CONCLUSIVE_TYPES` stays in step).
  - No wording change: Herald confirmed the chance is never shown to the player, and the badge's
    words now come out right.
- **Measured** (test_juror_listener's deal; a real Seer's "neither of these two is the Demon"):

  | Premise | Before | After |
  |---|---|---|
  | "is good" | ×1.14 | ×1.14 |
  | "is not the Demon" | ×1.14 | ×4.90 |

  The new check fails on the old code (×1.142 against ×1.142).
- **Golden:** identical to the CI baseline at `--tol 0`; two captures were identical.
- **Suites that pass:** test_juror_listener (+2 checks), test_badge_text,
  test_mechanics_conclusions, test_demon_when_hanged, test_social_credibility, test_workshop_why,
  test_workshop_live_canvas, test_town_note and test_juror_claims.
- **Proposed for the backlog:** none.
