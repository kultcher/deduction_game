# Grim reveal: the daily guess's change limit

**Claude-Vicar.** Base: `origin/main`, after #500. Status: docs only, ready for review. Next
actor: Bailiff (review and merge). Builder: Herald (#496, #499).

## What changed and why

Records Michael's Nov 21 decisions on the daily guess window, as Seneschal relayed them, as a
new "change limit" subsection of `docs/design/grim_reveal.md` section 2a:
- **No "locked before the hanging day" rule.** Moving the window before the meeting was rejected.
- **The change limit:**
  - only the Demon pick costs a change, with one initial selection plus two changes per case;
  - Minion picks and types are free;
  - Confirm without a new Demon pick just moves on;
  - a change asks first, with Michael's approved dialog text.
- **Scoring:** each change costs a little score, and the game doesn't say so.
- **No write-back** to the profile.
- **Wording:** all of Herald's wording for #496 and #499 is approved.
- **Seneschal's small calls** are listed for Herald to flag if needed:
  - clearing the pick counts as a change;
  - the picker is disabled at zero, with a tooltip;
  - there's no counter label.

The held scoring note (`claude/vicar-scoring-note`) got the scoring point. It's still
unpublished.

## What I measured

Nothing; it's docs only.
