# 2026-11-17, Claude-Quill: lie severity, the judge side (`claude/lie-severity`; moves golden)

- **Base:** main `317e040` (#194 merged). **Status:** PR open. **Next:** Bailiff (review,
  golden-moving: merge on its own). **Then Claude-Beadle:** the vote side of this item can
  start once it lands (see "For Beadle" below).
- **What (BACKLOG "Lie severity", [decided], Michael Nov 17: "yes to both, measure
  first"):** a good person's own "I was home" stops being certain. The judge used to treat
  it as hard, so a sighting that caught a good person out after "home" ruled out every
  world where they were good: proof of evil. New number
  `Tuning.Workshop.GOOD_OWN_ALIBI_OUT` = 0.2 (Michael picked it from the measured rate),
  the chance a good person who was out still says "home". Both kernels
  (`live_activity.gd` `_observed`, `LiveActivity.cs` `KindAlibi`). A witness's alibi for
  someone else stays hard. Evil's own alibi stays 0.7 out / 0.9 home. "Near the crime" is
  left to the existing scene reasoning, as agreed.
- **Measured first (Nov 17; 40 passive 10-NPC games, seeds 1–40, main `c676018`, every NPC
  asked each morning where they were the night before):** a good person who was out told
  the player "home" 26% of the time (51 of 199: 21 hiding a night gift, 19 a personal
  secret, 11 Sleepwalkers). Good people who were home always said so. Evil: 55% "home"
  when out, 92% when home.
- **In game terms (neutral juror, seven people, two evil, a kill on the Square on the first
  night; `tools/test_lie_severity.gd`), how sure the town is that the person is evil,
  starting from 33%:**

  | Caught | Before | After |
  |---|---|---|
  | "I was home", seen out away from the kill | certain | 51% |
  | "I was home", seen out at the kill scene | certain | 93% |
  | A Gravedigger reading for a day nobody was hanged | 99.9% | 99.9% |

- **Hanging rates in real games:** not measurable in passive play. Across 40 passive games
  per build, nobody publicly told a "home" lie that got caught; that takes the player
  pressing someone at the podium. The few "catches" were good people who really were home,
  framed by an evil sighting. An in-game rate needs active games with podium presses.
- **Golden:** re-baselined to `baseline_f554c4a`; see `docs/golden_baseline.md`. Only
  54875's outcome changes: a good Sleepwalker caught out on the night of the kill is no
  longer hanged for it, and the town hangs the Demon a day earlier.
- **Tests:** new `tools/test_lie_severity.gd` (in the fast list).
  `test_own_alibi_lies` and `test_sighter_contest` restated against the new rule: a good
  person caught out keeps the 0.2 chance; the contest checks compare against that floor.
  Passing on the merged tree: those three, `test_connections_pairings`,
  `test_connections_core`, `test_shared_model`, `test_delusional_reading`,
  `test_framed_defence`, `test_day_presence`.
- **For Beadle (the vote side, now unblocked when this lands):** the judge now reads a caught
  "home" lie as evidence (about 51% evil from a 33% start, away from the kill), not proof.
  The vote rules and "accepts the lie but won't hang, and says so" are yours; Herald drafts
  the lines for Michael.
