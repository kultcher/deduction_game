## Nov 20 — Claude-Lantern: word-against-word lie calls on the case slate

- **Base:** main. **Status:** PR open. **Next:** Bailiff. Tooling only: no game code changes, so
  golden is untouched.
- **Why:** Seneschal (Nov 19). These are the three word-against-word cases I measured for the
  player's-judgement boost (#352), now on the slate with their misleading twins, so the boost
  stays measured.
- **The cases** (`tools/case_slate.gd`). In each, a Minion bluffs the gift, the real holder
  reads, and the player files "X is evil" with a lie call on X's reading, grounded on the
  other's.
  - `lie_seer`: the Minion's Seer "yes" on two innocents, against the real Seer's "no".
  - `lie_gravedigger`: the Minion's Gravedigger reading that the hanged innocent was a Minion,
    against the real Gravedigger's.
  - `lie_seer_reversed`: the Minion's "no" on the Demon and an innocent, against the real
    Seer's "yes". The lie looks likely here.
  - Each `_innocent` twin is the misleading call, about the real holder, on the Minion's word.
  - Each row also records `lie_calls`, how the average listener takes each call.
- **Results** (10 deals each, on today's main, appended to `docs/case_slate/baseline.*`):

  | Case | Badge | Call | Town | Good yes votes (heard it) |
  |---|---|---|---|---|
  | lie_seer | Strong ×3.8 | pressed | +34 | 6.6 of 7 |
  | lie_seer_innocent | Moderate ×2.1 | draw | +14 | 1.4 of 6 |
  | lie_gravedigger | Strong ×8.7 | pressed | +46 | 6.0 of 6 |
  | lie_gravedigger_innocent | None ×1.1 | draw | +3 | 0.5 of 5 |
  | lie_seer_reversed | Moderate ×2.1 | draw | +22 | 2.4 of 7 |
  | lie_seer_reversed_innocent | Strong ×3.8 | pressed | +29 | 5.6 of 6 |

  - **The Seer and Gravedigger cases:** the true call wins and the misleading one doesn't. But
    the misleading Seer call still moves the town 14 points on the honest Seer: a lie call is a
    real accusation even when it draws.
  - **The reversed Seer case:** the town is fooled. The Minion's plausible "no" stands: the
    honest call only draws, and the misleading call on the real Seer is pressed and reaches the
    vote in 7 deals of 10.
  - This matches my Nov 19 measurement. The boost (×1.3 for an average listener) doesn't change
    the badge in any of the six. If Michael wants the town to resist a plausible lie, my Nov 19
    note stands: the lever is how readily the town credits a reading that merely looks plausible,
    not trust in the player.
- **Docs:** `docs/case_slate/README.md` describes the cases and `lie_calls`. The baseline
  report has a new section. The baseline's other rows are unchanged, still from 17dd113.
- **Proposed for the backlog:** none.
