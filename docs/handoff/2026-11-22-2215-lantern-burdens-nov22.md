# 2026-11-22, Claude-Lantern: belief-model work on the burdens branch, Nov 22 (`mock/burdens-slot`)

- **Base:** `mock/burdens-slot`. This entry covers everything from facb7262 through ce321a40.
- **Status:** pushed. Michael called a soft pause on Nov 22, so nothing new is started.
- **Next actor:**
  - Argon's vectorised pass is based on 5e25af5e. Merge it forward onto **the `mock/burdens-slot` tip after the main merge below lands** (or ce321a40 if the main merge hasn't landed yet). Lantern reviews it for beliefs.
  - Then Lantern cuts `claude/burdens` (burdens.md §10, Bailiff's checklist).
- **Golden:** this branch lands under one burdens re-baseline. Of the commits here, 7b532726, 353660eb and a72e81d5 move it; ce321a40 doesn't.

## What changed and why

| Commit | What | Why |
|---|---|---|
| facb7262 | `case_data["delusion_odds"]`, a hook for Quill's argued Delusion premise | Quill's juror |
| 710e29db | test_delusional_reading: a listener's own wrong reading is now excused in its own-Delusion worlds | Follows the shared Delusion doubt (Michael, Nov 22) |
| 0afe3db9 | `docs/DECISION_INSPECTOR.md`: what belief mode can't see (own readings, private tellings, own sightings and guards, whereabouts, the carried-over lean) | 51795 (Coroner) |
| 353660eb | Connections: one teller's readings from the same gift are judged as one item | 51795: Jory's three counts each cleared Odette against Kiran's dawn view of Jory |
| 7b532726 | The player's word on a secret counts as always arising, so it's worth the player's credibility alone (option b′) | Michael, Nov 22 |
| a72e81d5 | Connections: a reading item takes as context any burden claim, or player's word, about a person it names | The Marked badge and the town moved in opposite directions |
| ce321a40 | `workshop/demon_candidates.gd`: lazy P(Demon \| evil) per person, plus test_demon_candidates | Backlog item "top Demon candidates", for Beadle's Seer |

## What I measured

- **51795 at the day-3 meeting** (seq 948, the playtest build plus 353660eb):
  - Jory's counts clearing Odette in Kiran's eyes fell from −1.16 to −0.68 log-odds.
  - Jory's evil chance for Kiran went from 0.80 to 0.70; Fenwick's for Dorian from 0.55 to 0.45.
- **Autoplay, seeds 1–10, 10 NPCs, passive, 353660eb:**
  - Good won 6 of 10, against 4 before. Seeds 2 and 6 flipped; no other game changed length.
  - Wall time was about 19% higher. That figure is rough, because different jobs ran alongside each arm.
- **Slate, seeds 1, 3 and 4, after 7b532726 and a72e81d5:**

| Case | Badge | Town's suspicion of the subject |
|---|---|---|
| Seer yes-then-no, argued "Delusional" | Strong, 2.5% → 21% | +0.19 to +0.27 |
| marked_rescue | Strong, 84% Marked | −0.21 to −0.24 |
| marked_bluff | Strong, 84% | −0.12 to −0.22 |
| seer_once (control) | unchanged | unchanged |

- **Golden for ce321a40:** clean worktrees at a72e81d5, with and without the change. Identical on all 5 seeds at `--tol 0`.

## Waiting on Michael (through Seneschal)

- The player's word on a known burden X has already claimed: a reduced weight. Seneschal will put a middle option to him. Not built.
- Earlier items still open: Ill-Omened bluff strength; Beadle's "bluff a one-holder burden only when no living holder"; accusation as evidence about the accuser; gap 5 ("not seen out").

## For others

- **Argon:**
  - teller grouping slows refreshes. Autoplay ran about 19% slower.
  - test_connections_cache now needs 700–814 s, past the runner's 600 s default. Run it with `--timeout 1200`.
- **Beadle:**
  - `DemonCandidates.given_evil_of_npc(n)` is ready. Your stand-in is `sim/roles/seer.gd:75` `pick_targets`.
  - Please review `sim/mind_support.gd` on `mock/burdens-main-merge`.
- **Herald:** please review `sim/voices/*.gd` and `ui/daily_guess.gd` on `mock/burdens-main-merge`.
- **Main merge:** `mock/burdens-main-merge` (a6713ce4) is main merged into the branch tip, staged for that review. Once Herald and Beadle are happy, it merges into `mock/burdens-slot`.
- **Quill:** your Pass 3 odds can't fire in real play (the word card covers them). Removing them is yours, after Michael's call.

## Proposed for the backlog

None.
