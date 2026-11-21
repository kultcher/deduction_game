# Caught lying about me

- **Agent:** Claude-Beadle
- **Base:** main at `c1519a3` (`baseline_875370c`)
- **Branch:** `claude/beadle-caught-lying`
- **Status:** PR open. Golden moves (trust only; outcomes unchanged) and is re-baselined here to
  `baseline_01f5290`. Golden-moving PRs merge one at a
  time.
- **Next actor:** Bailiff (golden queue, review and merge).
- **BACKLOG item:** "Rapport and Warden-credit leftovers", part (a), unblocked by Anger reasons
  (#487). Michael's calls, Nov 21, via Seneschal: what counts, who pays, how much, and NPC-to-NPC
  trust only.

## What changed

- **The rule:** an NPC told something about itself that its own knowledge proves false trusts
  the teller less, by the public-accusation loss (`Tuning.Social.TRUST_ACCUSED_ME`, 0.1, reused).
- **What counts** (`Social.caught_lying`):
  - a sighting of it out on a night it spent at home;
  - a reading that names it alone as evil, when it is good.
  - A reading that names it among others proves nothing to it. Neither does a true evil
    reading of an evil NPC.
- **Who pays:** only the original teller, never someone passing it on. Once per teller and
  claim.
- **Where it's heard:**
  - private talk and the meeting's shared sightings (`Social._deliver`, which public sightings
    also go through);
  - a reading shared before the town (`MindMeeting._public_disclosure`);
  - the player pressing it with that teller's sighting (`MindPress.press`).
- **No voiced line**, as Michael chose. The trust change is logged as `npc_trust` with
  `why: caught_lying`.

## Small calls made on Michael's behalf

- **A falsehood, not only a fabrication:** the NPC can't tell a lie from an honest mistake, such
  as a poisoned or Delusional reader's wrong reading, so it reacts to anything it knows is
  false. Reacting only to real lies would make its distrust a tell of who lied, which it
  couldn't know.
- **The player's own cards don't count:** this is NPC-to-NPC trust only.

## Measured

- **New:** `tools/test_caught_lying.gd` (14 checks), on the fast list.
- **Codex on #506, fixed:** a Night Watch's route names who was out, not who is evil. It now
  counts only as a sighting, when it places the listener out on a night spent at home. A
  Medium's relayed reading never counts against the Medium.
- **Codex and Bailiff on #506, second round, fixed:**
  - **Only readings that assert evil count:** an allow-list of the PING, GROUP_COUNT,
    ROLE_AT_SITE and ROLE_IN_GROUP shapes, plus the Martyr and the Executor.
    - A Registrar's yes (it holds one of the listed roles, good ones included) never counts.
    - Neither does any other gift, until it's added.
  - **A public reading is checked for everyone it names,** so a faked route that adds someone
    who was home that night is caught. Golden was unmoved by this round.
- **Also pass:** test_agreement_trust, test_meeting_flow, test_social_credibility,
  test_caught_lie_softening, test_conversation_nights, test_npc_interactions,
  test_defence_repeats, test_dialogue.
- **Golden:** re-baselined to `baseline_01f5290`; two captures were identical.
  - Three seeds diverge, from day 2 or 3, through trust only.
  - The same people hang on every seed.
  - See "Current baseline" in `docs/golden_baseline.md`.

## Proposed for the backlog

None.
