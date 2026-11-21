# Evil's made-up street sightings need a claimed walking gift

- **Agent:** Claude-Beadle
- **Base:** main at `f8bc26d` (`baseline_b810754`, after #474), merged in
- **Branch:** `claude/beadle-street-claimed`
- **Status:** PR open. Golden moves on one seed (98933, outcome unchanged) and is re-baselined
  here to `baseline_5c5642c`. Golden-moving PRs merge one at a time.
- **Next actor:** Bailiff (golden queue, review and merge).
- **Asked by:** Michael, through Lantern (Nov 20): "we need to ensure that evil doesn't bluff night
  sightings that can't be explained by its actual claimed role". With Lantern's coming "a
  sighting places its teller", a street sighting now also says its teller was out on that
  block, so one told with no reason to be out incriminates the teller.

## What changed

- **The gap:** evil's daily planter picked a street frame ("I saw X out on the Market") by its
  *planned* bluff (a Night Watch, Warden or Lamplighter), not one it had claimed, and told it
  through `Evil.fake_night_sighting` whatever it had claimed so far. Seed 100002 (Hollis) is
  the case Lantern found.
- **The rule:** a made-up sighting seen "while out" (`how: street`) is told only once its teller
  has claimed a night-walking gift (`Evil.street_story_fits`). Until then it's held back, with
  a logged reason ("Holds back its made-up sighting of X on Y the first night: seen while out,
  and it has claimed no gift that takes it out at night"), once per night. A claim made in the
  same turn counts, since testimony claims before it accuses. Window sightings are unchanged.
- **Also covered:** the frame cited in an accusation (`MindMeeting._append_accusation_sighting`)
  and in a bluff reason (`Evil.bluff_reason`).
- The private-answer and podium paths were already sound: they take a street vantage only from
  a claimed duty or a night the teller had already owned.

## Small calls made on Michael's behalf

- **Any claim of a walking gift counts,** public or private (the teller's `claimed_role`), not
  only a public one: a private claim is what the listener heard too.
- **Held, not converted:** a held street frame isn't recast as a window sighting, since that
  would be a different lie (the frame's block is usually not the teller's own).

## Measured

- **New:** `tools/test_street_sighting_claimed.gd` (8 checks), on the fast list.
- **Also pass:** test_evil_play, test_relay_bluff, test_too_clean_bluffs, test_evil_owned_lie,
  test_meeting_flow.
- **A/B:** 40 passive games, seeds 6000-6039, 10 NPCs, against main.

  | | main | this PR |
  |---|---|---|
  | Street frames prepared by evil's planter | 51 | 49 |
  | ...told | 12 | 9 |
  | ...told with no walking gift claimed | 4 | 0 |
  | Frames held back until a claim | 0 | 6 |
  | Hangings, evil / good | 57 / 50 | 59 / 47 |
  | Wins, good / evil | 20 / 20 | 19 / 21 |

  In game terms: evil no longer says "I saw them out on the Market" before it has given any
  reason to have been out itself; it waits until it has claimed its walking gift. Outcomes
  barely move (one game in 40).
- **Golden:** re-baselined to `baseline_5c5642c`; two captures were identical. Only seed 98933
  moves, at day 2's meeting: evil no longer says it saw someone out on Chapel Hill on the second
  night, having claimed no walking gift. The same people hang. See "Current baseline" in `docs/golden_baseline.md`.
- **Also pass after the merge:** test_street_sighting_claimed, test_evil_play, test_relay_bluff,
  test_meeting_flow.

## Proposed for the backlog

None.
