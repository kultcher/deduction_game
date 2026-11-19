# Quill: Strong-tier cases on the case slate

Claude-Quill, Nov 19. Base: main at 4cf1d73. Status: PR open. Next actor: Bailiff
(review and merge; tooling and docs only, so golden can't move).

## What changed

Seneschal asked for one or two cases that reach the Strong tier, to show where they land
under the average-listener juror (#332). Three were added to `tools/case_slate.gd`, all
true cases with no misleading twin, since they're built on the real Seer's true readings
of the Demon:

- **seer_twice:** the Seer's "yes" on the Demon and one other, on nights 1 and 2.
- **vigil_seer:** a night-1 kill, the player's vigil seeing the Demon go out, and one Seer "yes".
- **stack:** the vigil at the kill, a witness's sighting on the victim's block, and both Seer readings.

`tools/case_slate_report.py` gains the cases and a `NO_TWIN` list. The baseline is
refreshed, and README and `baseline.md` say what moved.

## Measured (full slate, 10 deals per case, 239 rows, none blocked)

| Case | Average listener | Strength | Town | Badge now | Proposed cuts |
|---|---|---|---|---|---|
| seer_twice | 30% → 37% | 1.38 | +8 | none | Weak |
| vigil_seer | 33% → 48% | 1.85 | +23 | Weak | Weak (1 deal Moderate) |
| stack | 33% → 65% | 3.83 | +41 | Moderate | Strong |

Under the proposed cuts (×1.25 / ×2 / ×3.5, Damning at 90%), the true cases sort:
none 40, Weak 49, Moderate 31, Strong 10 (stack), Damning 10 (impossible). Town means by
tier are +3, +15, +21, +41 and +59.

Of the earlier 209 rows, 22 changed, only in the town's movement and by at most 0.26 of a
point. That's main moving since #332, likely the trust changes in #319, #321 and #330. No
badge, strength or category moved.

Not run: golden or suites. Nothing outside `tools/case_slate*` and `docs/` changed, and
no suite reads the slate.

## Proposed for the backlog

None.
