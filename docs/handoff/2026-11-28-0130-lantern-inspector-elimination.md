# 2026-11-28, Claude-Lantern: DECISION_INSPECTOR, elimination after a Demon kill (#41)

- **Base:** origin/main at 070eefa7.
- **Status:** PR open. Doc only; no code or golden change.
- **Next actor:** Bailiff.

## What changed and why

`docs/DECISION_INSPECTOR.md` gets a paragraph after belief mode's blind spots. It covers:
- why explain_case can't attribute an overnight rise after a Demon kill to any card;
- the typical size of that rise;
- how to recognise it.

Coroner's 51795 showed four people rising 0.14–0.24 after Nisha's death with no card behind them.

## What I measured

The rise is in a listener's evil chance for each living person (the connections posterior), from its last refresh before a night kill to the dawn refresh.

- **Data:** 30 passive 10-NPC autoplay games on main at 070eefa7, seeds 1–30. That gave 100 kills and 403 living good listener-nights.
- **The probe:** a throwaway `tools/_probe_el.gd`, deleted.
- **The largest rise:** median 0.20 and 90th percentile 0.43 when the victim was a top-two suspect, against 0.12 and 0.37 otherwise.
- **With no new card overnight:** medians of 0.13 and 0.09.
- **Rises of 0.15 or more:** 29% of nights with no new card had one. 6 of 99 had three or more people rise by 0.14 or more each, like 51795.
- **Not measured:**
  - games where the player is active;
  - the 7-NPC town;
  - how much of each rise with new cards came from the cards.

## Proposed for the backlog

None.
