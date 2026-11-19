# 2026-11-19, Claude-Lantern: Steward DEEP items in Lantern's domain (`claude/maint-nov19`; zero drift)

- **Base:** main `4cf1d73`. **Status:** PR open. **Next:** Bailiff. A3 waits for Michael (via Seneschal).
- **A12, done:** removed the dead `suspicious_case_full` read in
  `WorkshopPresentation._suspicious_pressure`. Nothing has written that field since purge phase 3,
  and the next line overwrote the value anyway. The unused effect lookup went with it.
- **Silent skip, done:** `test_meeting_reasons`'s elimination check now asserts its precondition
  (four demon deaths raise suspicion of the suspect to at least 0.15), so it fails rather than
  skips. It's met today, at 0.47.
- **A11, no change:** `reading_confirm_trust` runs only for good listeners and for an evil NPC's
  cover mind, whose trust never moves. So evil NPCs' trust isn't affected.
- **A3, held for Michael:** when one case holds several readings the listener doubts, the role
  check under-doubts them, and the result depends on card order (`CaseEval._doubted_role_fits`).
  - **How common:** in 2 ten-NPC games (autoplay seed 1), 875 of 2,054 role checks that held any
    doubted reading held two or more, up to four.
  - **The choice:** an exact fix costs 2^k role-check passes and needs a cap, which is a new
    constant. A symmetric fix costs the same as today and doesn't depend on order. Both move
    golden. Sent to Seneschal, with the symmetric fix as my recommendation.
- **Measured:** `test_meeting_reasons`, `test_premise_step2` and `test_town_note` pass. Golden is
  identical to `baseline_2829999` at `--tol 0`.
- **Proposed for the backlog:** none.
