# Herald: the case-strength badge's words

- **Agent:** Claude-Herald
- **Base:** Quill's `claude/badge-cut-points` (7cb991f) with `claude/lie-call-lines` (#351, ba71ffb) merged in. Either can merge first; this PR goes after both.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed

Michael approved the words on Nov 19, through Seneschal. Quill set the cut points and the top tier's key, `damning`. The wording is all in `ui/workshop_canvas_view.gd`.

- **Tiers:** the bottom tier now reads "Negligible" (was "Doesn't support"), then Weak, Moderate and Strong as before.
- **The top tier.** It is the `damning` key: the average listener puts the premise's chance at 90% or more.
  - On an accusation (a named target, a premise outside `PREMISE_CLEARS`, not a conflict), the chip reads "Damning". Its line: "This case is damning: an ordinary townsperson would vote for {name} over anyone else."
  - On any other premise, it reads "Conclusive". Its line: "This case is conclusive: an ordinary townsperson would take it as settled that {premise}." {premise} is the card's own title, such as "Edda is good".
  - Both chips are a deeper green (#3e7f47) with a thin gold ring, the gold of the portrait ring.
  - The lines replace Quill's placeholder `category_text("damning")` in the chip's tooltip. Quill's function is untouched.
- **Lie calls in the tooltip.** The premise chip's tooltip now lists each lie call's line (`Live.lie_call_line`), as in the Why readout.
- **Stand-off.** A lie-call card the test juror weighs as a draw gets a "Stand-off" tag above it. Its tooltip: "One word against another. Most will wait for more, but a few may take your side."
  - The draw is matched by card id to `listener.challenges[].reading` in any premise's badge.
  - The tag isn't drawn when the card already shows "Contradicted by", which uses the same spot.

## Measured
- **`test_badge_text`** (new, 6 checks, on the fast list):
  - Negligible.
  - The Damning line with the target's name.
  - The Conclusive line with the premise.
  - The drawn chip's tooltip carries the top-tier line, not the placeholder, plus the lie call's line.
  - A lie call is found by its card.
- **Suites:** `test_juror_listener`, `test_workshop_ui`, `test_workshop_live_canvas`, `test_workshop_nav` and `test_workshop_live_activity` pass.
- **Not tested:** the Stand-off tag drawn on a real lie-call card. No test builds a real draw on the canvas; the lookup it uses is tested.
- **Golden:** UI only; this PR changes no simulation code.

## Proposed for the backlog
None.

## Codex fix (#358)
- **The problem:** the top tier's chance is the target's chance of being evil (or of being good, for clearing premises), whatever the premise. A case that makes someone 90% likely good therefore reached the top tier on "holds their claimed gift", "is Marked" or "told the truth". The Conclusive line would then call that premise settled, though being good doesn't settle it.
- **The fix:** Conclusive now shows only where being good settles the premise ("is good", "is not the Demon"). Any other clearing premise's chip shows the tier its evidence alone earns, from Strong down.
- **Damning is unchanged:** its line is about who the town would vote for, which the evil chance does speak to.
- **For Quill:** whether the cutoff itself in `CaseEval.category` should skip those premise types.
- **Tests:** `test_badge_text` (now 10 checks) covers a gift premise reading Strong, and Weak when that's all its evidence earns.
