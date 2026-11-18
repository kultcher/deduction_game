# 2026-11-18, Claude-Lantern: the player's "failed gift" call as testimony (`claude/player-failed-gift`; built on #232)

- **Base:** `claude/poison-self-doubt` (#232) at `a03c68a`, since both change `SourceDoubt.derive`.
  **Status:** branch pushed; the PR opens once #232 is on main, so it shows only this change.
  **Next:** Bailiff (review), then Quill (the 10-seed before/after for Michael).
- **What (Michael, Nov 18, option C; `docs/design/poisoned_not_lying.md`):** a "failed gift"
  challenge in one of the player's presented cases is the player's word that the reading was
  poisoned. Each listener sets an honest doubt on that reader's night: one witness as accurate
  as its trust in the player (c), against the chance the reader was poisoned that night (π,
  Quill's outing-aware `poison_chance` from #252): π·c / (π·c + (1 − π)(1 − c)). The split with
  Quill: he built the judge side (the outing link, the track-record entry); this is the belief
  side.
- **Small calls made on Michael's behalf:**
  - Only "failed gift" (impaired) calls take this route. A "Delusional" challenge keeps the
    judge's own handling, and "misled" keeps its discount inside its case.
  - Only the player's cases, not an NPC's nomination (Michael: NPCs making the same call, not
    now).
  - Nothing spreads the freed suspicion on purpose (agreed with Quill).
  - A listener doesn't otherwise put a poison chance on another person's reading, so even at
    even trust the call weighs poison at its plain chance; it never lowers a doubt.
- **Measured** (`tools/test_player_failed_gift.gd`, 6 checks; seed 692, 7 NPCs, a good Archivist's
  night-0 reading naming two good people, poison chance 5%): the reader's chance of being evil,
  with the call weighed against without it: even trust 43% → 42%; trust 0.7 42% → 40% (doubt
  11%); trust 0.9 42% → 35% (doubt 32%). One call moves a listener a few points; no sheep.
- **Golden: zero drift.** Identical at `--tol 0` on all five seeds to #232 alone (`a03c68a`):
  the golden player presents no cases.
- **Tests:** new suite added to the fast list; the suites that touch source doubt and the poison
  chance pass.
- **Codex on #270 (both fixed):**
  - A call on a relayed reading lands on the side the challenge names. `transmission` is the
    Medium's night; `original` is the dead reader's own reading and night.
  - A call on a Registrar's night-0 register carries no poison doubt, since it can't be poisoned.
    A Medium's transmission of it still can be.
  - `test_player_failed_gift` has 10 checks, including a guard that the unchanged call does carry
    a doubt.
- **Codex on #270 (fixed):** the call's doubt goes in before the Gravedigger and Executor proofs
  and again after the sincere-teller pass, as #245's "my gift may have been turned" does
  (`SourceDoubt._player_failed_gift`). So a verdict called poisoned no longer proves at full
  strength. In the test, a trusted Gravedigger's "the hanged Odette was the Poisoner" puts 0.85
  doubt on Odette's word uncalled, and none when called poisoned at near-full trust.
- **`test_connections_cases`** pins the new pass off. It checks case arithmetic on chosen
  numbers, including "a challenge acts only inside its own case", and option C makes the
  player's "failed gift" call the one deliberate exception (`docs/belief_model.md`).
