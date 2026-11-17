# 2026-11-17, Claude-Vicar: centring a case on its premise, a design note (`claude/vicar-premise-centring`, docs only)

- **Base:** main after #211. **Status:** PR open, docs only. **Next actor:** Seneschal puts it to Michael; Bailiff merges.
- **What changed:** new `docs/design/premise_centring.md`, written at Michael's request (via Seneschal) from Claude-Lantern's measurements on `mock/premise-centre`. It covers:
  - what options A, B and C each do, in game terms;
  - the measurements (10 bot games, 318 presentations; six examples, with Lantern's corrected example 1);
  - the "move doubt onto the subject" idea against the guardrails;
  - costs (one new constant, the approved bystander share; C adds movement judgements);
  - a recommendation and the calls for Michael.
- **Recommendation:** build C at 0.5 (measure 0.25 too), drop A and B, and hold "doubt onto the subject". Through NPC nominators' cases it would let evil's invented sightings go undoubted. Look at the night-0 movement odds separately.
- **Revised the same day (Michael's follow-up):** the goal is "what's in focus": the player mustn't win by supplying information, but by making and presenting the right connections. Against that goal C does little (night cards are set aside), and B is the closest fit. B is in effect the Nov 5 premises decision (step 1's spillover damping), rebuilt for the connections model. The recommendation is now B, pending a misframed-case test (section 8), requested from Lantern through Seneschal.
- **Added `docs/design/premises_plan_review.md`** (Michael's request): which parts of `docs/premises_plan.md` are gone, still live, or unbuilt under connections. Two things for Lantern to confirm: the wrong-premise trust cost, and whether the player's-word secret card reaches the connections refresh.
- **Nothing decided;** BACKLOG unchanged.
- **Measured:** nothing myself. The figures are Lantern's (seeds 1–10, 10 NPCs, bot games; examples from seeds 1–6 at 0.5).
