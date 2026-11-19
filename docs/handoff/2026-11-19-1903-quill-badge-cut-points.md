# Quill: the badge's cut points

Claude-Quill, Nov 19. Base: main. Status: PR open. Next actor: Bailiff. Herald builds the
badge text on top. Golden is identical.

## What changed

These are Michael's cut points (Nov 19), from the slate's vote measure (#355):

| Tier | From | Category key |
|---|---|---|
| Negligible | below ×1.25 | `none` |
| Weak | ×1.25 | `weak` |
| Moderate | ×2 | `moderate` |
| Strong | ×3.5 | `strong` |
| Damning / Conclusive | the premise's chance for the Test juror's average listener at 90% or more, whatever the strength | `damning` (new) |

The old cut points were ×1.5, ×3 and ×10.

- `sim/tuning.gd`: `LR_WEAK` 1.5 → 1.25, `LR_MODERATE` 3 → 2, `LR_STRONG` 10 → 3.5, and the
  new `LR_DAMNING_CHANCE` 0.9, which Michael approved. `tuning_catalogue.md` is regenerated.
- `CaseEval.category(lr, chance = -1)` gives `damning` at that chance. The Test juror passes its
  listener's chance. `_rank` and `strength_from` know the new tier.
- `category_text("damning")` reuses the Strong sentence as a placeholder. Herald builds the
  Damning/Conclusive lines in `ui/workshop_canvas_view.gd`, and the chip shows the raw key
  until then.
- BACKLOG notes the slate's gap: nothing sits between Strong and Damning.

## In game terms

On the slate, the true cases sort as:

| Tier | Cases | Good votes swayed |
|---|---|---|
| Negligible | 50 | none |
| Weak | 59 | about 1.6 |
| Moderate | 21 | about 3 |
| Strong | 10 | about 4, and with the player's vote the nomination carries 9 times in 10 |
| Damning | 10 | every good vote |

Before, the impossible reading was the only Strong case.

No NPC reads the category. Outside the badge, it feeds only the strength reason line ("It
rests on one card") and the board's pivotal cards for the reference listener. Golden is
identical on all five seeds.

## Tests

- `test_case_eval`: one check moved. "One Surveyor count alone is at most weak evidence" was
  ×2.2, Weak under the old cuts and Moderate under the new ones. It now asserts "can't be
  strong", which keeps the comment's intent. A tier-boundary check is added.
- These pass:
  - `test_case_eval`
  - `test_connections_cases`
  - `test_decision_inspector`
  - `test_dialogue_decisions`
  - `test_dialogue_opinion_pass`
  - `test_fixes_crowd_augur_lovers_pan`
  - `test_juror_listener`
  - `test_roles_official`
  - `test_ui_controls`
  - `test_workshop_regressions`
  - `test_workshop_why`

## Proposed for the backlog

None.
