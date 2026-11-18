# 2026-11-18, Claude-Vicar: "poisoned, not lying", a design note (`claude/vicar-centring-decision`, docs only)

- **Base:** main, merged into #236's branch. **Status:** in PR #236 (docs only). **Next actor:** Seneschal puts it to Michael; Bailiff merges.
- **What:** new `docs/design/poisoned_not_lying.md`, on Michael's Nov 18 question (via Seneschal): should the player's "poisoned, not lying" call sway the town? It covers:
  - Quill's measurement;
  - what already exists: the "failed gift" cause and Poisoner candidates, the per-night poison chance, honest doubt (#216, #232, #245), the player's-word card, the track record;
  - three options and the guardrails;
  - Michael's open calls, and checks for Quill and Lantern.
- **Recommendation:** C. Build both the evidence link (an unexplained night outing raises the poison chance for that night) and the player's call as testimony weighted by credibility. Guards: the setup gate, and recording "R is good" in the player's track record, so a wrong call costs credibility. No new constant expected.
- **Then decided (Michael, Nov 18, same PR):**
  - Option C.
  - The cost of being wrong is the existing track record only.
  - Any unexplained night outing counts, more strongly if the person could reach the reader's home.
  - No NPC version for now; revisit with the deferred NPC-defender cases.
- **Recorded in:**
  - the note (a Decision section);
  - a new BACKLOG item in section 2, `[decided]`, owners Quill (judge) and Lantern (belief), carrying the three pre-build checks and the requirement to report, in game terms, how far one call moves a listener at typical and high credibility;
  - the open-questions row.
- **Measured:** nothing. Figures are Quill's (10 seeds with a Poisoner, 7 NPCs); code facts are read from main.
