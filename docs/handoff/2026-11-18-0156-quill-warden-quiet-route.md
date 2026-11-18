# 2026-11-18, Claude-Quill: a Warden's guard on a quiet night sets the Demon's route (`claude/warden-quiet-route`; zero drift)

- **Base:** main (`878ddaa`). **Status:** PR open. **Next:** Bailiff (review); Lantern (review: it's
  in the shared judge, though golden doesn't move); Herald (the UI half, on top of this branch).
- **What (BACKLOG "Quiet-night evidence argued by the player", [decided] Nov 17, judge side):**
  - The player's held ward already became a Demon attack at that door (the scorched sigil, Oct 26).
  - The gap was a Warden. Now a Warden's guard report on a night the Demon killed nobody counts
    too, with or without a claimed save. In worlds where the Warden and the guarded person are
    both good, the Demon's walk that night ended at the guarded door.
  - It holds at the claimed-save reliability (`WARDEN_SAVE_RELIABILITY`, 0.7). That's divided by
    1 + the other living Veteran claimants, as in the Warden's own save belief.
  - In other worlds the route is untouched. Nothing is certain except the public "no one died".
  - **How:** `LiveActivity._quiet_guards` computes the Demon's profile with the attack added, for
    each subset of the guards. The kernel (`GuardedDemon` in `LiveActivity.cs`) mixes over which
    guards held, per world, like the sighter contests. It applies to the walking Demon only.
  - **The Test juror:** `WorkshopCanvas.guard_reasons` re-judges with the guards off. If the
    subject moved by at least `REASON_MIN_ITEM_CONTRIB`, `result.guards` lists {warden, guarded,
    night, saved, report, quiet, shift} for Herald's reason line. `CaseEval`'s compiled key
    carries the switch, as it does the Hexer's.
- **Michael's decision (Nov 18, via Seneschal):** the listener's doubt of the Warden cuts the
  route too, not only the report's role check. `CaseEval._route_trusted` gives copies of the
  Warden reports a `route_trust`: 1 − the listener's honest doubt of the reading
  (`reading_doubt`), times any challenge that holds against the report or its teller. The
  route's reliability is scaled by it. Measured on the 7-person test view, d's chance as the
  subject: 0.60 trusting the Warden, 0.53 at half doubt, 0.44 with no route. Reason
  attribution's compile reads it the same way.
- **Codex on #243 (both fixed):**
  - Scion succession branches now carry the guards on both sides.
  - The juror credits each guard with its own effect (leave-one-out through
    `LiveActivity.quiet_guards_skip`), and lists only the guards the route uses.
- **Small calls made on Michael's behalf:**
  - A guard report without a claimed save counts the same as one with: the quiet is the
    judge's inference either way.
  - At most 3 guards per case, the latest nights first (`QUIET_GUARD_MAX`, a code limit in
    `workshop/`, not a tuning value).
- **Measured:**
  - **The seed-4460 juror case** (7 NPCs): a sighting of the Demon on the guarded block weighs
    1.96 alone and 3.31 with the Warden's report. With the route off, the report gives 1.84.
    The subject's chance rises about 15 points.
  - **Unit checks on a 7-person view:** being seen on the guarded block that night makes a
    suspect likelier the Demon (3.7 → 10.9 against an unseen rival). Being seen on another
    block makes them less likely.
  - **Golden:** identical on all five seeds at `--tol 0`.
  - **Autoplay** (seed 1, 10 NPCs, the first 5 of 8 games): the guard never reached the judge.
    The bot's cases don't cite Warden reports, and NPC beliefs didn't hit it in these games.
    So in practice this is the player's argument, as the item intends.
- **Tests:** new `tools/test_warden_quiet_route` (23 checks), added to the fast list. Also
  passing: `test_warden_challenge`, `test_demon_types`, `test_workshop_regressions`,
  `test_workshop_live_activity`, `test_evidence_cards`, `test_juror_claims`,
  `test_workshop_remaining`, `test_workshop_integration`, `test_workshop_ui`,
  `test_workshop_ui_1110`, `test_workshop_why`.
- **Docs:** DESIGN "Warden saves" gains the route paragraph. BACKLOG item gains a judge-side
  built note.
- **Not done:** the Veteran's "came by way of" shape and the player's own quiet-night card
  aren't new links here (the sigil already covers the player's ward). There's no reason line
  or wording: that's Herald's half, for Michael.
