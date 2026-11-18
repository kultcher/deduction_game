# 2026-11-18, Claude-Lantern: the player's "failed gift" call, stronger (`claude/failed-gift-strength`; zero drift)

- **Base:** main `3aef738`. **Status:** PR open. **Next:** Bailiff, then Quill (10-seed check).
- **What:** Michael (Nov 18, through Seneschal, with Quill): the player is the expert, so a
  listener takes a "failed gift" call at its credibility in the player.
  - **The line:** the call's honest doubt runs straight from `FAILED_GIFT_DOUBT_LOW` (0.2) at the
    lowest credibility (`CRED_MIN` 0.1) to `FAILED_GIFT_DOUBT_HIGH` (0.8) at the highest
    (`CRED_MAX` 0.9). It's 0.5 at the starting credibility (`SourceDoubt.call_doubt`).
  - **Quill's refinement:** never less than the earlier one-witness weighing, so an outing near
    the reader's home still strengthens a call.
  - **The gate:** as before, only where the poison chance isn't zero.
  - **New constants:** two, approved by Michael on Nov 18. `tuning_catalogue.md` is regenerated.
- **Target:** one call removes about a fifth, half and four-fifths of what the reading costs its
  reader at low, default and high trust.
- **Measured** (`test_player_failed_gift`, seed 692's Archivist case, poison chance 5%; fully
  doubting the reading removes 6.5–7.5 points here):

  | Trust | Doubt | Without → with | Share of the reading's cost removed |
  |---|---|---|---|
  | 0.1 | 0.2 | 0.348 → 0.325 | 31% |
  | 0.5 | 0.5 | 0.343 → 0.297 | 66% (was 0.343 → 0.336) |
  | 0.9 | 0.8 | 0.338 → 0.280 | 89% |

  - **Quill's 10 seeds:** expected near 20 / 52 / 82%; Quill confirms on this branch.
  - **This case vs those seeds:** it runs higher than Quill's seeds, where the reading costs
    less.
- **A wrong call still costs credibility at any strength:** dawn's `Credibility._agreement`
  rebuilds the listener's view without the player's ledger entries (checked with Quill).
- **Golden:** identical to `baseline_e287b3d` on all five seeds, since the bot never makes the
  call.
- **Tests:** fast list 116/116. `test_player_failed_gift` has 13 checks (was 11): the line's
  ends and middle, and the one-witness weighing winning where it's more.
