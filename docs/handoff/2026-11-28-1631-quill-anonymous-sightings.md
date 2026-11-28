# Quill: unnamed sightings and private relays as evidence (for Beadle's "passing on hides the source")

- **Agent:** Claude-Quill
- **Base:** main at 38d38666
- **Status:** PR open
- **Next actor:** Bailiff, to review and merge. Then Beadle switches relayed sightings to the anonymous form, and Lantern opens his small model PR (testimony cards stay out of teller grouping; a privately passed-on account counts in full).

## Why

Michael, Nov 28: passing on someone else's information hides its source, everywhere. Beadle builds the behaviour. This PR is the evidence side: the card shape the Workshop and the board accept, merged first so Beadle can switch to it.

## What changed

1. **An unnamed night sighting, or daytime meeting** (Beadle's "ask about") is `kind: sighting` or `conversation`, `source: ""`, `anonymous: true`, `via` = the teller. This matches what an unnamed reading already was.
   - **The fact** (`live_evidence.normalize_card`) keeps the teller and blanks the source, so its id carries no trace of the witness.
   - **The Workshop** (`live_assessment.anonymous_sighting_card`, used by the live assessment and the canvas) makes it the teller's account:
     - the sighting it reports, with `source` = the teller;
     - `testimony_only`, and, told at the meeting, `hearing_weight` = `RELAY_WEIGHT`. The movement model reads `hearing_weight`, not the readings' reliability map (Codex on #602);
     - it doesn't place the teller there (`teller_place_eligible` already skips testimony);
     - seen in the evening, it's an evening card, and the evening likelihood now honours the relay weight too (`LiveActivity.cs` `KindEvening`, and `live_activity_profiles._observed`). It used to rule out every other evening block outright. Firsthand evening cards weigh 1, so nothing else moves (Codex's second finding on #602).
   - A missing or unknown teller is refused with an issue.
2. **The board** (`CardModel.place_markers`) draws an anonymous card as "someone told you" (hollow), never as the player's own sighting. An empty source used to read as firsthand.
3. **A relay passed on in private** (`hearing: "private"` on the receipt, now carried into the fact):
   - the Workshop card is marked `private_relay`, and an unnamed Night Watch sighting takes no relay weight of its own;
   - this applies to sightings and readings alike (`testimony_card`);
   - Lantern's listener skips its relay discount on those cards, so private hearsay keeps the ledger's 0.75 × trust in the teller, as Michael wants. That's Lantern's PR (#599, merged).
   - **A Night Watch account passed on in private** is read as a sighting, and the movement model reads its hearing weight, not the reading's reliability. So it counted as certain. `SharedLedger.prepare` now gives it the same private-hearsay weight it gives the reading (Codex's third finding on #602; this is Lantern's file, so Lantern should look). One told at the meeting keeps `RELAY_WEIGHT`, as before.

## Weighing (Lantern's call, Nov 28: accept, no cap)

On the Test juror, an unnamed sighting reads 1.02 and the same sighting from a named witness 0.94, on seeds 1–3.
- A named sighting also places its witness out that night (Nov 20), and that weakens it; an unnamed one places no one.
- Before Codex's finding the unnamed one read 1.61, because no hearing weight reached the movement model.
- Lantern: the hidden witness gives up being checked or rebutted, and that's paid for at relay weight. Nobody can choose anonymity to strengthen a case.

## What I measured

- **New:** `test_anonymous_sighting`, 14 checks, 0 failures, on the fast list. It checks:
  - the fact keeps the teller and no witness;
  - the board draws it hollow;
  - a case on it is ready, and the Workshop card is the teller's testimony;
  - a meeting relay is heard at relay weight and isn't marked private;
  - an unnamed meeting keeps the teller, is drawn hollow, and is the teller's testimony;
  - an unnamed evening meeting is heard at relay weight and leaves other evening blocks possible;
  - a private Night Watch account heard at 0.4 moves whereabouts at most that much (it fails without the fix);
  - a private sighting and a private reading are both marked private relays, and the sighting has no relay weight of its own;
  - both the named and the unnamed sighting are weighed.
- **Related suites:** `test_workshop_live`, `test_workshop_live_canvas`, `test_workshop_secrets`, `test_workshop_ui`, `test_board`, `test_board_fixes_marks_crowd`, `test_sighting_followup`, `test_night_sighting_rebuttal`, `test_juror_listener`, `test_juror_claims`, `test_meeting_flow`, `test_workshop_regressions`, `test_ui`, `test_medium_relay_challenge`, `test_roles_dead`, `test_conversation_nights`, `test_conversation_gifts`. All pass.
- **Golden:** identical to `baseline_2e97efe` on all five seeds. No play path makes anonymous sightings yet.

## For Beadle

Board cards for an unnamed sighting should carry `source: ""`, not the witness's name. The board's hover strings read the card's own `source`, and the Workshop blanks it either way. Always set `via`. Two passed-on sightings of the same person, place and night are one observation and merge, as named ones do. Unnamed meetings take the same form, as `kind: conversation`.

## Small calls made on Michael's behalf

- The anonymous form is used for sightings as for readings, rather than a separate relay flag, so one rule covers both.

## Proposed for the backlog

None.
