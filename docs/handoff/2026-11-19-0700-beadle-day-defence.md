# A defence's answer to a daytime-whereabouts case

- **Agent:** Claude-Beadle
- **Base:** main, merged up to the latest on Nov 19
- **Branch:** `claude/beadle-day-defence`
- **Status:** PR open. It's zero drift: golden is identical on all five seeds.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "A defence's answer to a daytime-whereabouts case" (26532, #171; Michael,
  Nov 16, and the plan approved Nov 19 with no evil lie). Marked built. The false-name version
  is tabled (#308 carries that note).

## What changed

**When it fires.** At a nomination, when the heaviest item against the nominee is a daytime
sighting. For the player's filed case, that's the heaviest item the case cites. Before this, a
case like that got no answer of its own, and the defence moved on to the next item.

**What the nominee says.** Where they were and who else was there, from the public whereabouts
for that place and phase (`MindMeeting._day_whereabouts_defence`):
- **with others there:** `defence_day_others`, naming up to three: "I was at the mill yesterday
  afternoon, and so were Jory and Kiran. Ask any of them what they saw.";
- **with someone they suspect there:** `defence_day_others_pointed_stand`. For a good defender,
  that's its own suspicion at the nomination floor (0.40); for an evil one, the town's view.
- **with nobody else there:** `defence_day_alone`.

**Details.**
- **The voice lines:** Herald's lines, already approved and committed. Only the `_stand`
  variants are used, since this fires only at a nomination.
- **Evil defenders:** tell it truthfully (Michael, Nov 19).
- **The player:** gets a sighting card for the defender and for each person named.
- **How listeners hear it:** as a plea (the existing hearing scale, `DEFENCE_PLEA_RELIEF`). No
  new constant.

## Measured

- **New suite:** `tools/test_day_defence.gd` (9 checks), on the fast list. It covers the three
  lines, the cards (only for those named, Codex on #318), not firing when a heavier item isn't a daytime sighting, and an evil defender
  naming only who was really there.
- **Suites that pass:** test_mechanics_defences, test_defence_repeats, test_meeting_flow,
  test_meeting_m2c, test_wording_89077, test_dialogue_voices and test_evil_play.
- **How often, in play:** 15 passive 10-NPC games, seeds 3000-3014. It fired at none of 144
  nominations. Passive games have no player case and no case resting on a daytime sighting. It's
  meant for the player's filed cases and for a day sighting passed on as evidence, as in 26532,
  so the suite is the measure here.
- **Golden:** identical on all five seeds.

## Proposed for the backlog

None.
