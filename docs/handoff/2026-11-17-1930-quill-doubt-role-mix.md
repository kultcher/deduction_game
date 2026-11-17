# 2026-11-17, Claude-Quill: the doubted role check's mix (`claude/doubt-role-mix`; golden identical)

- **Base:** main `ae6c304` (#210 merged). **Status:** PR open. **Next:** Bailiff (review and
  merge; golden doesn't move). **Then Claude-Lantern:** the Delusional self-doubt can go
  through the role check as well as the weight (both paths, as Lantern first designed).
- **What:** a fix to #186's `CaseEval._doubted_role_fits`. A reading the listener doubts
  honestly is read as genuine with the listener's trust, and otherwise as broken. The broken
  side was counted as certain to say exactly what it said, so the doubt weighed about
  1/(chance the words hold) too much: double for a Clerk reading. Now the broken side is
  weighted by `chance_content(card)`, the share of worlds where the reading's words hold,
  which is the ordinary likelihood mixture.
- **Measured (hand-made case, now in `test_role_check_doubt`):** seven people, two evil;
  someone claims Seer; the listener is a Clerk whose own reading says "one of {a, the Seer
  claimant} is the Dowser". How sure the listener is that a is evil: 33% on the claim alone,
  9.1% with the reading. A doubt should give back about its own share of that move.

  | Doubt | Before | After | The plain mix |
  |---|---|---|---|
  | 10% | 12.3% | 10.8% | 11.5% |
  | 30% | 18.2% | 14.7% | 16.4% |

  The new check fails before the fix and passes after.
- **Not affected:** readings whose content chance is 1, such as a Psychologist's. Lantern's
  earlier 0.84 → 0.57 report was two different games, not this; at one fixed state Jory on
  Constance (seed 100055) is 0.755 with or without the doubt, through either path.
- **Golden:** identical to `baseline_f554c4a` (all five seeds). In the golden games no
  doubted role-checked reading with content chance below 1 changes an outcome.
- **Tests run:** `test_role_check_doubt` (17 checks), `test_beliefs`, `test_lie_severity`,
  `test_connections_core`.
- **Also in this PR:** BACKLOG item "Keep Tally's trace probe as a tool" ([decided], Michael
  Nov 17, owner Quill).
- **Next for Quill (Seneschal's order):** the vigil change (watch who leaves the block, #211),
  then Tally's trace probe as a tool. The poison self-doubt waits for Michael's pick.
