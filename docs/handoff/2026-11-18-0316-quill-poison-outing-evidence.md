# 2026-11-18, Claude-Quill: poison evidence from night outings, and the failed-gift track record (`claude/poison-outing-evidence`; zero drift)

- **Base:** main (`0a9f672`, after #243). **Status:** PR open. **Next:** Bailiff (review).
  Then Lantern's half: the player's call into honest doubt, in `source_doubt.gd`, which calls
  `poison_chance(view, listener, night, reader)`. After both, Quill re-runs the 10-seed
  measurement as the "after".
- **What:** my half of "poisoned, not lying", option C (Michael, Nov 18;
  `docs/design/poisoned_not_lying.md` on #236). The split was agreed with Lantern.
  1. **(A) The outing link.** `ReadingChallenges.poison_chance` takes an optional `reader`.
     With one, it reads the night's outings (`_outing_poison_chance`). The Poisoner is out
     every night of play and walks to the victim's home block (sim/world.gd). So each person
     seen out that night with no claimed night gift or confided secret may be the Poisoner,
     and where they were seen says whose door they could have been going to.
     - **w**, the chance this walker is the Poisoner: the prior (a Poisoner in play, as one of
       the others alive) against how often a good person is out. That comes from the
       movement model's good profile (`LiveActivity.good_walk_chance`, now reading the same
       `PROFILE_RATES`): about one night in four for an unclaimed person, one in ten for a
       claimed home-staying gift. The walkers are exclusive (one Poisoner), so the w are
       capped at 1.
     - **t**, the chance the reader was the victim if this walker is the Poisoner: shared
       evenly by those whose home the walker could have been heading to by way of every block
       they were seen on (`C.route`), counted at the good share of the town. It's 0 if the
       reader's home isn't among them.
     - **The chance** = sum(w × t) + (1 − sum(w)) × base. No new number.
     - Without `reader`, nothing changes, so the poison self-doubt's call (#232) is unchanged.
  2. **The track record.** A presented case with an `impaired` ("failed gift") or `misled`
     challenge on R's reading records "R is good" with each listener
     (`Credibility.record`). It never overwrites a conclusion the case itself states about R
     (Codex on #252).
- **Effect in game terms** (7 people, two evil, a Poisoner certain on the script, reader
  sharing the docks with one neighbour). The chance the reader's gift was poisoned that night:

  | What the cards show | Chance |
  |---|---|
  | No outings | 1 in 5 (0.20) |
  | Someone with no night errand seen on the reader's block | about 2 in 5 (0.38) |
  | Two such people seen there | about 3 in 5 (0.56) |
  | Seen on a block away from the reader's (going elsewhere) | about 1 in 9 (0.11) |
  | Seen with no block named, or on their own block | 1 in 5 (unchanged) |
  | The same, with a Poisoner only possible (one of two minions) | 0.13 from 0.10 |
  | The walker claims a night gift, has a Sleepwalker secret, or is known good | unchanged |

- **Small calls made on Michael's behalf:**
  - **Seen somewhere that rules out the reader lowers the chance.** Michael's note said an
    outing "raises" it. But a Poisoner seen heading to another door is evidence the reader
    wasn't the victim, so the chance falls rather than staying put.
  - **An outing with no block named doesn't raise it when the Poisoner is certain.** If a
    Poisoner is surely in play, it poisoned someone that night anyway, so an outing with no
    location says nothing about whom. It raises the chance only when the Poisoner's presence
    is in doubt.
  - **"Misled" records "R is good" as well as "failed gift".** Both say the teller was honest
    but wrong.
- **Golden:** identical to `baseline_44073d9` on all five seeds at `--tol 0`. Nothing calls
  the reader form yet, and the passive player presents no cases.
- **Tests:** new `test_poison_outing` (17 checks: the outing link and the track record),
  added to the fast list. Also passing: `test_poison_chance`,
  `test_workshop_reading_challenges`, `test_warden_challenge`, `test_premise_step2`,
  `test_premise_step3`, `test_connections_cases`, `test_social_credibility`,
  `test_workshop_regressions`, `test_workshop_live_activity`, `test_warden_quiet_route`.
- **Also (Seneschal's small call, Nov 18):** `test_mechanics_sightings` now pins BACKLOG
  "Conversation sightings should also cover location sightings" in both orders. A same-phase
  visit and a seen talk give one sighting card per talker plus the talk card, because the
  sightings share a fact id and merge.
- **Docs:** DESIGN gains "Poison evidence from night outings" after Source doubt. The BACKLOG
  item comes with Vicar's #236.
