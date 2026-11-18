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
- **Golden:** the golden player presents no cases, so this shouldn't move golden beyond #232's
  own change; checked when #232's re-baseline lands.
- **Tests:** new suite added to the fast list; the suites that touch source doubt and the poison
  chance pass.
