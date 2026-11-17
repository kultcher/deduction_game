# 2026-11-17, Claude-Beadle: a liar who notices tells a better lie (`claude/beadle-better-lie`; moves golden)

- **Base:** main `c676018` (#186) merged in, then main `59a387c` (#196, batch 1). **Status:** PR open. **Next actor:** Bailiff (golden-moving: merge on its own, re-baseline included).
- **Why:** Michael's answer on #188's held readings (via Seneschal, Nov 17): "when the liar notices, it should re-think the fabrication and come up with a better lie", not just hold it back.
- **What changes in play:**
  - A liar who notices its made-up reading would point the town at itself or a teammate now looks through its gift's other plausible readings: another count over the same crowd, the other yes/no, someone else in the pair or as the target, or a different role for the hanged.
  - Of those that point at nobody on its team, it tells the one that still pushes the scapegoat hardest.
  - Only when none fits does it hold the reading back. A held reading is now checked again on the day it would be told, so it may be told then, become a better lie, or be held again.
  - Every choice is logged with its reason (`think`, topic `lie`): "tells a better lie instead: says 1 evil on square instead".
- **Gifts that can offer alternatives (13), in their own words:** Dowser, Hearthwitch, Lamplighter, Seer, Surveyor, Augur, Magistrate, Archivist, Clerk, Rumormonger, Executor, Martyr, Gravedigger. A new role hook, `bluff_alternatives`, returns up to six, drawing only on people outside the evil team (`bluff_bystanders`).
- **Not yet (hold back, re-checked daily):** Chronicler, Confessor, Monitor, Registrar, Psychologist; their bluff rules are more involved. Night Watch and Medium still aren't checked.
- **Removed:** #188's "ask the bluff rule again" retry and its `release_bluff_use` hook (Dowser, Martyr), which this replaces.
- **Measured** on the same 20 passive ten-NPC games as #188 (seeds 1000–1019, scratch probe, not committed):

  | | #188 (after the Dowser fix) | This PR |
  |---|---|---|
  | Made-up readings | 144 | 129 |
  | Self-incriminating | 16 (about 1 in 9) | 17 (about 1 in 8) |
  | … noticed, became a better lie | 1 | 8 |
  | … noticed, held back | 11 | 4 |
  | … slipped through | 4 | 5 |

  - In game terms: a liar who notices now finds a safer story 2 times in 3 (8 of 12), where before it nearly always just waited a day.
  - The holds that remain are Gravedigger readings about a hanged teammate. Once the town is sure the hanged was evil, every role the Gravedigger could name gives the liar away, so it waits.
  - The slips are the Insight roll, as intended.
  - The totals differ because the games diverge once a better lie changes what's said.
- **Correction to my #188 entry:** it says no fabrication was ever reworked. That was before the Dowser fix; afterwards 1 of 12 noticed readings was (PR #188 comment). This PR replaces that mechanism.
- **Tests:** `tools/test_fabrication_check.gd`:
  - on the 26532 shape, a sharp liar turns "Greta and Lian shared an alignment" into "did not share" 16 times in 20 (the rest it doesn't notice);
  - every role's alternatives carry matching text and never name the teller.

  The fast list and the bluff-rule suites pass: 69/69 before the main merge; `test_fabrication_check`, `test_role_check_doubt`, `test_evil_play` and `test_gravedigger_bluff` after it.
- **Golden:** new `baseline_85e9b36`; two seeds diverge (54875: Constance tells a better Dowser count on day 3; 900: Isolde's held Gravedigger reading is re-checked and slips out on day 3); all outcomes and votes unchanged. Details in `docs/golden_baseline.md`.
- **BACKLOG:** Michael's decisions recorded on Nov 17 (via Seneschal):
  - removing the Demon detour from inference;
  - the pressure-of-silence pitch;
  - lie severity;
  - the kill-score pass;
  - the evil Medium's night-0 frame;
  - frame memory, scaled by Insight and Confidence;
  - the pass over every bluffer;
  - the reluctant-town Gravedigger;
  - surveying bus-throwing;
  - corroborators and visible evil meetings, both staying open.

  My order for them is in my messages to Seneschal; next is the Medium's night-0 frame.
