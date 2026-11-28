# Withheld readings: NPCs ask, press and answer; the refusal record

- **Agent:** Claude-Beadle
- **Base:** main at `7b9a63c5` (`baseline_1bf8a4b`)
- **Branch:** `claude/beadle-withheld-asks`
- **Status:** PR open. Moves golden, re-baselined here (`baseline_446c9c2`).
- **Next actor:** Bailiff (review and merge). Then Lantern builds the cost off
  `w.withheld_refusals`.
- **Item:** BACKLOG "Withheld readings: asking for what someone hasn't said" [decided].
  Un-held, and all five constants approved, by Michael on Nov 28 (via Seneschal).

## What changed

- **New `sim/mind_withheld.gd`.**
  - **Asking in private** (`maybe_ask_private`, called from `Social.converse` both ways
    before anything is shared): a good NPC that heard someone claim an information gift a day
    or more ago, privately or before the town, and has heard no reading from them since, asks
    for it. The chance is `ASK_PRIVATE_BASE` 0.10 + `ASK_PRIVATE_WARY` 0.30 × its suspicion of
    the claimant + `ASK_PRIVATE_INSIGHT` 0.10 × its Insight. At most once per pair per day,
    with Herald's `ask_reading_private` line.
    - **"Owed"** means a first-night gift or an ongoing information gift. A gift that reads
      only after a hanging (the Gravedigger) isn't owed.
  - **The private answer** (`answer_private`) goes to the asker alone:
    - **A good holder** shares on the normal private-sharing willingness (its openness and its
      trust in the asker), pushed by `CALL_ON_PRESSURE_BUMP` as if under that much more
      pressure.
    - **Held back:** it defers with a reason (friend, burden, or distrust of this asker), or
      deflects.
    - **A reading held for an Unrequited's beloved** is a "burden" deferral.
    - **A bluffer** gives its made-up reading, backfilling a first-night one if its bluff
      lacks one. With none, it says "nothing more", logged as a lie.
  - **Pressing at the meeting** (`meeting_press`, in each testimony turn after the accusation):
    a good NPC with Confidence at least `PRESS_WITHHELD_CONFIDENCE_MIN` 0.6 can press a public
    claimant. The claimant must:
    - be suspected at the accusing level (`GOOD_ACCUSE_MIN_SUSP`);
    - have claimed an owed gift on an earlier day;
    - have given the town no reading since.
    - The chance is `PRESS_WITHHELD_SCALE` 0.25 × Confidence. It presses the one it suspects
      most, at most once per meeting, with Herald's `press_withheld` line.
    - `{when}` is "yesterday", or "the second day".
    - The claimant answers on the "Call on" rules, with the presser as the asker.
- **`MindCallOn.respond(w, n, asker_id = "player")`:** the asker can be an NPC. Distrust is
  then read from the claimant's trust in that NPC, and the distrust line names it. The spoken
  refusal moved to `refusal_line`, shared with the private answer. Every deferral or
  deflection is recorded.
- **The refusal record** is `w.withheld_refusals`, plus a `withheld_refusal` log entry. Each
  entry carries:
  - `asker` (NPC id or "player") and `claimant`;
  - `claim: {day, role}`, the night of the dodged reading and its gift ("" for a night
    sighting held back from a Call on);
  - `tick` (workshop/chronology.gd's clock) and `day`;
  - `venue` and `kind`;
  - `reason`;
  - `known_to`: always a list, `[asker]` or `["public"]`;
  - `shared_at`, set on every matching entry when the reading comes out: told to that asker
    in private (`Social._deliver`), or before the town (`_go_public`).
  - The shape is the one agreed with Lantern (Nov 23, with Lantern's three asks on Nov 28).
- **`sim/tuning.gd`:** the five approved constants, `ASK_PRIVATE_*` in `Tuning.Social` and
  `PRESS_WITHHELD_*` in `Tuning.Meeting`. `tuning_catalogue.md` is regenerated.
- **Docs:** the BACKLOG item and the design note's status say asking and answering are built.

## Measured

- **New:** `tools/test_withheld_asks.gd`, 17 checks, on the slow CI list (about 2.5 minutes).
  - **Private asks:** 11 asks out of 80 owed pairs, against about 14.5 expected from the
    approved formula. Never twice a day, and never when nothing is owed: a claim made today, a
    reading already heard, a Gravedigger's claim, or an evil asker.
  - **Private answers:**
    - closed claimants that distrust the asker held back in 28 of 40 cases, each on the
      record with the asker alone knowing;
    - opened up later, 22 told the asker, and each refusal got `shared_at`;
    - bluffers answered with the made-up reading in 23 of 23 cases.
  - **Meeting presses:**
    - at full Confidence, 19 of 80 qualifying meetings saw a press (approved chance 0.25);
    - the presser speaks the press and the claimant speaks the answer, once per meeting, never
      below the Confidence floor or short of the accusing level;
    - an Unrequited claimant holding back a reading about its beloved refused 33 times, each
      recorded as public with the presser as asker.
  - **Call on:** 27 refusals of the Demonologist's ask were recorded with asker "player". Each
    got `shared_at` when the reading later came out before the town.
  - **Night sightings (Codex on #588):**
    - a sighting held back from a Call on gets `shared_at` once volunteered (24 of 24);
    - a pressed claimant's sighting reaches the town as the claimant's (17 of 17; 2 without
      the fix).
- **Also pass:** test_call_on_respond, test_call_on (every voice has both new lines),
  test_conversation_gifts, test_silenced_shares_nothing, test_dialogue_voices,
  test_dialogue_fixes_testimony, test_silence_pressure.
- **Golden:** moves on seed 42 only, re-baselined as `baseline_446c9c2`. Two captures were
  identical at `--tol 0`.
  - On day 2, Kiran asks Fenwick in private what the Medium showed. Fenwick has no reading
    yet and says so. That extra roll moves later draws: Fenwick, not Dorian, nominates Agnes.
  - The same hanging and the same win for good.
  - The other four seeds are identical: no roll was made there.
  - `docs/golden_baseline.md` has the details.
- **In bot games:** 4 autoplay games (seed 1) and the five golden seeds produced one ask
  (seed 42, above) and no press. Claimants nearly
  always give the reading with the claim, so a reading that's owed and missing is rare, as
  the design wants ("now and then").
- **Not measured:** how often a playing human sees a press.

## Small calls made on Michael's behalf

- **Who counts as owed:** first-night and ongoing information gifts, but not a gift that reads
  only after a hanging.
- **How the private answer decides to share:** the existing private-sharing willingness (its
  weight against idle talk), pushed by `CALL_ON_PRESSURE_BUMP`. No new constant.
- **A bluffer asked in private** always gives its made-up reading when it has one. Overall
  that's "mostly answers": with none, it says it has nothing more.
- **Whom the meeting press targets:** the qualifying claimant the presser suspects most.
- **A Call on that shares something else** (a sighting) while still holding a reading counts
  as shared, not refused, as before.

## Proposed for the backlog

None.
